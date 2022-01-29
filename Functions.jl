module Functions
using LinearAlgebra

mutable struct Circle
    x::Float64 
    y::Float64
    R::Float64
    Points::Any # index of intersection points located on Circle object
    Circles::Any # index of intersection circles located on Circle object
    Contained::Bool # 1 if the Circle object is completely contained by another circle, 0 if not
end

mutable struct Point
    x::Float64
    y::Float64
    Circles::Any # index of the 2 Circle objects that make up the intersection point
    ID::Bool # 1 if point is on contour, 0 if point contained within a circle, 
end

# Euclidean distance between centres of 2 Circle objects
function distance(A::Circle,B::Circle)
    distance = sqrt((A.x-B.x)^2 + (A.y-B.y)^2)
    return distance
end

# Checks if 2 circle objects are coincident or not
function coincident(A::Circle,B::Circle)
    d = distance(A,B)
    if d == 0 && A.R == B.R
        return true
    end
end

# Takes in 2 Circle objects, returns Cartesian intersection coordinates - two Tuple{Float64,Float64}
function intersection(A::Circle,B::Circle)
    d = distance(A,B)

    if d > A.R + B.R            #non-intersecting
        return nothing
    elseif d < abs(A.R - B.R)   #one circle within another
        contained(A,B)
        return nothing
    elseif d == 0 && A.R == B.R #coincident circles
        return nothing
    else
        a = (d^2+A.R^2-B.R^2)/(2*d)
        h = sqrt((A.R^2-a^2))

        varx = A.x + a*(B.x-A.x)/d
        vary = A.y + a*(B.y-A.y)/d

        x1 = varx + h*(B.y-A.y)/d
        y1 = vary - h*(B.x-A.x)/d
        x2 = varx - h*(B.y-A.y)/d
        y2 = vary + h*(B.x-A.x)/d

        if x1 == x2 && y1 == y2
            contained(A,B)
            return nothing
        end

        return x1,y1,x2,y2
    end
end

# check if one Circle object within another Circle object
function contained(A::Circle,B::Circle)
    d = distance(A,B)
    if d <= abs(A.R - B.R)
        if A.R < B.R
            A.Contained = true
        else
            B.Contained = true
        end
    end
end

# Take a Point object and checks if its within Circle object
function boundary(A::Circle,point::Point)
    x = point.x
    y = point.y
    
    if round((x-A.x)^2 + (y-A.y)^2 - A.R^2, digits=8) < 0 #inside circle
        return false
    else return true
    end

end

# returns x and y vectors of a Circle object (for plotting)
function draw(A::Circle,theta1,theta2)
    if theta1 > theta2
        theta2 = theta2 + 2*pi
    end
    arr = LinRange(theta1,theta2,101)
    return A.x .+ A.R*cos.(arr), A.y .+ A.R*sin.(arr)
end

# sort a Vector of points (Circle or Point objects) anticlockwise
function sort_acw(Points,mean_x,mean_y)

    for i in range(1,stop=length(Points))
        for j in range(i+1,stop=length(Points))
            ax = Points[i].x
            ay = Points[i].y
            bx = Points[j].x
            by = Points[j].y

            det = (ax-mean_x)*(by-mean_y) - (bx-mean_x)*(ay-mean_y)

            if det < 0
                tmpx = Points[i]
                Points[i] = Points[j]
                Points[j] = tmpx
            end

        end
    end
    return Points
end

# sort a vector of Point objects relative to a Circle object in ascending order of Polar angle
function sort_asc_angle(A::Circle, array)
    for i in range(1,stop=length(array))
        for j in range(i+1,stop=length(array))
            theta1 = mod(atan(array[i].y-A.y,array[i].x-A.x),2*pi)
            theta2 = mod(atan(array[j].y-A.y,array[j].x-A.x),2*pi)
            if theta2 < theta1
                temp = array[i]
                array[i] = array[j]
                array[j] = temp
            end
        end
    end
    return array
end

# returns a Point object given a Circle object and Polar angle 
function point_on_circle(A::Circle,theta)
    x = A.x + A.R*cos(theta)
    y = A.y + A.R*sin(theta)

    return Functions.Point(x,y,[],0)
end

# get area from a sorted (ACW/CW) vector of points (Circle or Point objects) using Shoelace Method
function shoelace(Points)
    xarr = [point.x for point in Points]
    yarr = [point.y for point in Points]

    dum1 = dot(xarr,circshift(yarr,1))
    dum2 = dot(yarr,circshift(xarr,1))

    area = 0.5*broadcast(abs,(dum1-dum2))
    
    return area
end

function area_sector(array)
    circle,theta1,theta2 = array
    if theta1 > theta2
        theta2 = theta2 + 2*pi
    end

    angle = theta2 - theta1

    area = 0.5*circle.R^2*angle

    return area
end


# Vector: Any length vector, with each row of form [[Association_Object(s)], Any_Other_Objects]
# Returns a vector, with each row containing rows in the original Vector that have links between the Association Objects
function associate(Vector)
    global dummy = []
    push!(dummy,Vector[1])
    splice!(Vector,1)

    final = []

    if size(Vector)[1] == 0
        push!(final,dummy)
    else
        while size(Vector)[1] != 0
            super_break = false

            for i in range(1,stop=size(dummy)[1])
                for j in range(1,stop=size(Vector)[1])
                    var1 = dummy[i][1]
                    var2 = Vector[j][1]

                    common = intersect(var1,var2)

                    if size(common)[1] != 0 # there exists a common object
                        push!(dummy,Vector[j])
                        splice!(Vector,j)
                        super_break = true
                        break
                    end

                    if i == size(dummy)[1] && j == size(Vector)[1] # no more common objects between original vector and vector of associated objects
                        push!(final,dummy)
                        global dummy = []
                        push!(dummy,Vector[1])
                        splice!(Vector,1)
                    end
                    
                end

                if super_break
                    break
                end
            end

            if size(Vector)[1] == 0
                push!(final,dummy)
            end

        end

    end

    return final
end

end #module end