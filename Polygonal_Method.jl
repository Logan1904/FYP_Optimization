N = 6

circles = []
for i in range(1,stop=N)
    x,y = rand(-10:10,2)
    R = rand(2:5,1)[1]

    push!(circles,Functions.Circle(x,y,R,[],[],false))
end

#get intersection points for all circles
intersections = []
to_delete = []
for i in range(1,stop=length(circles))
    for j in range(i+1,stop=length(circles))
        coords = Functions.intersection(circles[i],circles[j])

        if coords == "coincident"
            push!(to_delete,j)
            continue
        elseif isnothing(coords) == false
            x1,y1,x2,y2 = coords
            A = circles[i]
            B = circles[j]

            P1 = Functions.Point(x1,y1,[i,j],1)
            P2 = Functions.Point(x2,y2,[i,j],1)
            push!(intersections,P1)
            push!(intersections,P2)

            dum = size(intersections)[1]
            push!(A.Points,dum-1,dum)
            push!(B.Points,dum-1,dum)

            push!(A.Circles,j)
            push!(B.Circles,i)
        end

    end
end
deleteat!(circles,to_delete)

# obtain boundary ID -> 1: on outer contour, 0: contained inside contour
for i in range(1,stop=size(intersections)[1])
    point = intersections[i]

    for j in range(1,stop=length(circles))
        circle = circles[j]
        
        ID = Functions.boundary(circle,point)

        if ID == 0
            point.ID = ID
            break
        else
            continue
        end

    end
end

# form polygons
polygon = []
big_polygon = []
for i in range(1,stop=length(circles))
    for j in range(i+1,stop=length(circles))
        shared_points_index = intersect(circles[i].Points, circles[j].Points)

        storage = []
        for k in range(1,stop=size(shared_points_index)[1])
            point = intersections[shared_points_index[k]]

            if point.ID == 0
                push!(storage,k) # store index of shared point (only non-contour point) between 2 circles
            end

        end

        splice!(shared_points_index,storage) # obtain index of shared points that are contour points

        if size(shared_points_index)[1] == 0 # no shared contour points
            continue
        elseif size(shared_points_index)[1] == 2 # 2 shared contour points -> a 4 sided polygon
            push!(polygon,[circles[i],circles[j],intersections[shared_points_index[1]],intersections[shared_points_index[2]]])
        elseif size(shared_points_index)[1] == 1 # 1 shared contour point -> part of a bigger >4 sided polygon
            push!(big_polygon,[[circles[i],circles[j]],intersections[shared_points_index[1]]])
        end
        
    end
end

# form big polygon points
if size(big_polygon)[1] != 0

    big_polygon = Functions.associate(big_polygon)

    #unpack and form unique points of big polygon
    for i in range(1,stop=size(big_polygon)[1])
        storage = [] 
        for j in range(1,stop=size(big_polygon[i])[1])
            A,B = big_polygon[i][j][1]
            point = big_polygon[i][j][2]
            push!(storage,A,B,point)
        end

        storage = unique(storage)

        push!(polygon,storage)
    end
end

# sort polygon points ACW and obtain area
area = 0
for i in range(1,stop=size(polygon)[1])
    if size(polygon[i])[1] == 4 # for 4 sided polygon, sort acw with centre as the average of the 2 circular centres
        dummy = [point for point in polygon[i] if isa(point,Functions.Circle) == true]
        mean_x = sum([point.x for point in dummy])/2
        mean_y = sum([point.y for point in dummy])/2

        polygon[i] = Functions.sort_acw(polygon[i],mean_x,mean_y)
    else # for >4 sided polygon, sort acw/cw by jumping between points and seeing which circle is shared

        if typeof(polygon[i][1]) == Functions.Circle
            polygon[i] = circshift(polygon[i],1)
        end

        dummy = []
        A = [point for point in polygon[i] if typeof(point)==Functions.Point]

        push!(dummy,A[1])
        splice!(A,1)

        while size(A)[1] != 0
            for j in range(1,stop=size(A)[1])
                point = A[j]
                prev_point = last(dummy)

                point_circles = circles[point.Circles]
                prev_point_circles = circles[prev_point.Circles]

                common_circle = intersect(point_circles,prev_point_circles)

                if size(common_circle)[1] != 0
                    push!(dummy,common_circle[1])
                    push!(dummy,point)
                    splice!(A,j)
                    break
                end
            end
        end

        first_point_circles = circles[dummy[1].Circles]
        last_point_circles = circles[last(dummy).Circles]

        common_circle = intersect(first_point_circles,last_point_circles)

        push!(dummy,common_circle[1])
        polygon[i] = dummy
    end
    var = Functions.shoelace(polygon[i])
    global area = area + var
    println("Area of polygon ",i,": ",var)
end

# form circle associations
contour = []
contour_circles = [point for point in circles if point.Contained != 1]
for i in range(1,stop=length(contour_circles))
    A = contour_circles[i]
    push!(contour,[A.Points,A])
end

contour = Functions.associate(contour)

# change into vectors of circles
for i in range(1,stop=size(contour)[1])
    contour[i] = [point[2] for point in contour[i]]
end

# form circular sectors
sectors = []
for i in range(1,stop=size(contour)[1])

    if size(contour[i])[1] == 1 # just the circle
        push!(sectors,[contour[i][1],0,2*pi])
        continue
    end

    for j in range(1,stop=size(contour[i])[1]) # obtain circular sectors for each circle 
        circle = contour[i][j]
        index = circle.Points
        boundary_points = [intersections[x] for x in index if intersections[x].ID == 1]

        boundary_points = Functions.sort_asc_angle(circle,boundary_points)
        theta = [mod(atan(point.y-circle.y,point.x-circle.x),2*pi) for point in boundary_points]

        for k in range(1,stop=length(theta))
            next_iterator = mod1(k+1,length(theta))

            if k == length(theta)
                half_angle = 0.5*(theta[k]+theta[next_iterator]) + pi
            else
                half_angle = 0.5*(theta[k]+theta[next_iterator])
            end

            point_check = Functions.point_on_circle(circle,half_angle)

            A = circles[circle.Circles]

            for l in range(1,stop=length(A)) # check if point_check is inside any of the circles that intersect our current circle
                outside = Functions.boundary(A[l],point_check)
                if outside == 0
                    break
                elseif l == length(A)
                    push!(sectors,[circle,theta[k],theta[next_iterator]])
                end
            end

        end

    end
end

# area of circular sectors
for i in range(1,stop=length(sectors))
    var = Functions.area_sector(sectors[i])
    global area = area + var
    println("Area of sector ",i,": ",var)
end

println("Total area: ",area)