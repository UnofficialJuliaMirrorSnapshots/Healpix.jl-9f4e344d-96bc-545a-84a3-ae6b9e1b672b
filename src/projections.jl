# Map projections

export UNSEEN,
    lat2colat, colat2lat,
    project,
    equiprojinv, mollweideprojinv, orthoinv,
    equirectangular, mollweide, orthographic

import RecipesBase

const UNSEEN = -1.6375e+30

"""
    project(invprojfn, m::Map{T, O}, bmpwidth, bmpheight; kwargs...) where {T <: Number, O <: Order}

Return a 2D bitmap (array) containing a cartographic projection of the
map and a 2D bitmap containing a boolean mask. The size of the bitmap
is `bmpwidth`×`bmpheight` pixels. The function `projfn` must be a
function which accepts as input two parameters `x` and `y` (numbers
between -1 and 1).

The following keywords can be used in the call:

- `center`: 2-tuple specifying the location (colatitude, longitude) of the sky
  point that is to be placed in the middle of the image (in radians)
- `unseen`: by default, Healpix maps use the value -1.6375e+30 to mark
  unseen pixels. You can specify a different value using this
  keyword. This should not be used in common applications.

Return a `Array{Union{Missing, Float32}}` containing the intensity of
each pixel. Pixels falling outside the projection are marked as NaN,
and unseen pixels are marked as `missing`.
"""
function project(invprojfn, m::Map{T,O}, bmpwidth, bmpheight,
                 projparams = Dict()) where {T <: Number, O <: Healpix.Order}

    center = get(projparams, :center, (0, 0))
    unseen = get(projparams, :unseen, UNSEEN)
    desttype = get(projparams, :desttype, Float32)

    img = Array{desttype}(undef, bmpheight, bmpwidth)
    masked = zeros(Bool, bmpheight, bmpwidth)

    anymasked = false
    for j in 1:bmpheight
        y = 2 * (j - 1) / (bmpheight - 1) - 1
        for i in 1:bmpwidth
            x = 2 * (i - 1) / (bmpwidth - 1) - 1
            visible, lat, long = invprojfn(x, y)
            if visible
                value = m.pixels[Healpix.ang2pix(m, lat2colat(lat), long)]
                if ismissing(value) || isnan(value) || (
                    !ismissing(unseen) && unseen == value)
                    img[j, i] = NaN
                    masked[j, i] = true
                    anymasked = true
                else
                    img[j, i] = value
                end
            else
                img[j, i] = NaN
            end
        end
    end

    img, masked, anymasked
end

################################################################################

lat2colat(x) = π / 2 - x
colat2lat(x) = π / 2 - x

@doc raw"""
   lat2colat(x)
   colat2lat(x)

Convert colatitude into latitude and vice versa. Both `x` and the
result are expressed in radians.
"""
lat2colat, colat2lat

################################################################################

"""
    function equiprojinv(x, y)

Inverse equirectangular projection. Given a point (x, y)
on the plane [-1, 1] × [-1, 1], return a tuple (Bool, Number, Number)
where the first Boolean is a flag telling if the point falls
within the projection (true) or not (false), and the two numbers
are the latitude and colatitude in radians.
"""
function equiprojinv(x, y; kwargs...)
    ((-1 ≤ x ≤ 1) && (-1 ≤ y ≤ 1)) || return (false, 0, 0)
     
    (true, π / 2 * y, π * x)
end

"""
    function mollweideprojinv(x, y)

Inverse Mollweide projection. Given a point (x, y) on the plane,
with x ∈ [-1, 1], y ∈ [-1, 1], return a 3-tuple of type
(Bool, Number, Number). The boolean specifies if (x, y) falls within
the map (true) or not (false), the second and third arguments are
the latitude and longitude in radians.
"""
function mollweideprojinv(x, y; kwargs...)
    # See https://en.wikipedia.org/wiki/Mollweide_projection, we set
    #
    #     R = 1/√2
    #
    # x ∈ [-1, 1], y ∈ [-1, 1]

    if x^2 + y^2 ≥ 1
        return (false, 0, 0)
    end

    sinθ = y
    cosθ = sqrt(1 - sinθ^2)
    θ = asin(sinθ)

    lat = asin((2θ + 2 * sinθ * cosθ) / π)
    long = -2 * π * x / (2cosθ)
    (true, lat, long)

end

"""
    function orthoinv(x, y, ϕ1, λ0)

Inverse orthographic projection centered on (ϕ1, λ0). Given a
point (x, y) on the plane, with x ∈ [-1, 1], y ∈ [-1, 1], return
a 3-tuple of type (Bool, Number, Number). The boolean specifies
if (x, y) falls within the map (true) or not (false), the second
and third arguments are the latitude and longitude in radians.
"""
function orthoinv(x, y, ϕ1, λ0; kwargs...)
    # Assume R = 1/√2. The notation ϕ1, λ0 closely follows
    # the book "Map projections — A working manual" by
    # John P. Snyder (page 145 and ff.)
    
    R = 1
    ρ = √(x^2 + y^2)
    if ρ > R
        return (false, 0, 0)
    end
    
    c = asin(ρ / R)
    sinc, cosc = sin(c), cos(c)
    if cosc < 0
        return (false, 0, 0)
    end
    
    if ρ ≈ 0
        return (true, ϕ1, λ0)
    end
    
    ϕ = asin(cosc * sin(ϕ1) + y * sinc * cos(ϕ1) / ρ)
    if ϕ1 ≈ π / 2
        λ = λ0 + atan(x, -y)
    elseif ϕ1 ≈ -π / 2
        λ = λ0 + atan(x, y)
    else
        λ = λ0 + atan(x * sinc, (ρ * cos(ϕ1) * cosc - y * sin(ϕ1) * sinc))
    end
    
    (true, ϕ, λ)
end

################################################################################

"""
    equirectangular(m::Map{T,O}; kwargs...) where {T <: Number, O <: Order}

High-level wrapper around `project` for equirectangular projections.
"""
function equirectangular(m::Map{T,O}, projparams = Dict()) where {T <: Number, O <: Order}
    width = get(projparams, :width, 720)
    height = get(projparams, :height, width)
    project(equiprojinv, m, width, height, projparams)
end

"""
    mollweide(m::Map{T,O}; kwargs...) where {T <: Number, O <: Order}

High-level wrapper around `project` for Mollweide projections.
"""
function mollweide(m::Map{T,O}, projparams = Dict()) where {T <: Number, O <: Order}
    width = get(projparams, :width, 720)
    height = get(projparams, :height, width ÷ 2)
    project(mollweideprojinv, m, width, height, projparams)
end

"""
    orthographic(m::Map{T,O}, ϕ0, λ0; kwargs...) where {T <: Number, O <: Order}

High-level wrapper around `project` for orthographic projections centered around the point (ϕ0, λ0).
"""
function orthographic(m::Map{T,O}, projparams = Dict()) where {T <: Number, O <: Order}
    width = get(projparams, :width, 720)
    height = get(projparams, :height, width)
    ϕ0, λ0 = get(projparams, :center, (0, 0))
    project(m, width, width, projparams) do x, y
        orthoinv(x, y, ϕ0, λ0)
    end
end

################################################################################

RecipesBase.@recipe function plot(m::Map{T,O},
                                  projection = mollweide,
                                  projparams = Dict()) where {T <: Number, O <: Order}
    
    img, mask, anymasked = projection(m, projparams)

    if anymasked
        RecipesBase.@series begin
            seriestype --> :shape
            primary --> false
            c --> :grey
            line --> :grey

            width, height = size(mask)
            xm = Float64[]
            ym = Float64[]
            for y in 1:height
                curx = 1
                # Instead of drawing each single masked pixel as a
                # square, squash together long runs of masked pixels
                # into one rectangle
                while curx ≤ width
                    if mask[curx, y]
                        startx = curx
                        while curx ≤ width && mask[curx, y]
                            curx += 1
                        end

                        append!(xm, [
                            startx - 0.5,
                            startx - 0.5,
                            curx + 0.5,
                            curx + 0.5, NaN
                        ])
                        append!(ym, [
                            y - 0.5,
                            y + 0.5,
                            y + 0.5,
                            y - 0.5, NaN])
                    else
                        curx += 1
                    end
                end
            end

            ym, xm
        end
    end

    seriestype --> :heatmap
    aspect_ratio --> 1
    colorbar --> :bottom
    framestyle --> :none
    
    img
end

@doc raw"""
    plot(m::Map{T,O}, projection = mollweide, projparams = Dict())

Draw a representation of the map, using some specific projection. The
parameter `projection` must be a function returning the
bitmap. Possible values for `projection` are the following:

- `equirectangular`
- `mollweide`
- `orthographic`

You can define your own projections, if you wish.

The dictionary `projparams` allows to hack a number of parameters used
in the projection.

# References

See also [`equirectangular`](@ref), [`mollweide`](@ref), and
[`orthographic`](@ref).

"""
plot
