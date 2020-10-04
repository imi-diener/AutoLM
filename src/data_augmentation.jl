import Statistics: mean
using Printf
using DelimitedFiles
import Images
import ImageFiltering
using Base.Threads
using MultivariateStats
using Statistics
#data augmentation
"""
    flip_volume_front(x, y)

Flip a volume so that the longitudinal (x) axis becomes the vertical (z) axis
and adjust the landmakr coordinates accordingly.
"""
function flip_volume_front(x, y)
  newx = zeros(Float32, size(x,3),size(x,2),size(x,1),size(x,4))
  newy = deepcopy(y)
  Threads.@threads for ind in 1:size(y,2)
    for z in 1:size(x, 1)
      newx[:,:,z,ind] = transpose(x[z,:,:,ind])
    end
    for cor in 1:3:size(y,1)
      newy[cor, ind] = y[cor+2, ind]
      newy[cor+1, ind] = y[cor+1, ind]
      newy[cor+2, ind] = y[cor, ind]
    end
  end
  return newx, newy
end

"""
    flip_volume_side(x, y)

Flip a volume so that the lateral (y) axis becomes the vertical (z) axis
and adjust the landmark coordinates accordingly.
"""
function flip_volume_side(x, y)
  newx = zeros(Float32, size(x,2),size(x,3),size(x,2),size(x,4))
  newy = deepcopy(y)
  Threads.@threads for ind in 1:size(y,2)
    for z in 1:size(x, 2)
      newx[:,:,z,ind] = x[:,z,:,ind]
    end
    for cor in 1:3:size(y,1)
      newy[cor, ind] = y[cor, ind]
      newy[cor+1, ind] = y[cor+2, ind]
      newy[cor+2, ind] = y[cor+1, ind]
    end
  end
  return newx, newy
end

"""
    function mirror_vol(x, y)


A form of data augmentation. Mirrors a volume (exchanges x and y axis) and returns
concatenation of original data and mirrored data.
"""
function mirror_vol(x, y)
  copyx = x
  copyy = y
  copyx = cat(x, copyx, dims=length(size(x)))
  copyy = hcat(y, copyy)
  inds = size(x)[length(size(x))]
  for ind in 1:inds
    for slice in 1:size(x)[3]
      if length(size(x)) == 5
        trans = x[:,:,slice, 1, ind]
        copyx[:,:,slice, 1, ind+inds] = trans'
      else
        trans = x[:,:,slice, ind]
        copyx[:,:,slice, ind+inds] = trans'
      end
    end
    for cor in 1:3:size(y)[1]
      copyy[cor, ind+inds] = y[cor+1, ind]
      copyy[cor+1, ind+inds] = y[cor, ind]
    end
  end
  return copyx, copyy
end

"""
  flip_2D(x, y)

Takes 2D images in a 4D tensor and landmark data in 2D tensor and returns
the flipped (clockwise) images, aswell
as the coordinates for the flipped images. only works on square images.
"""
function flip_2D(x, y)
  copyx = zeros(Float32, size(x, 2),size(x, 1),size(x, 3),size(x, 4))
  copyy = deepcopy(y)
  inds = size(y, 2)
  size_x = size(x, 1)
  for i in 1:inds
    for cor in 1:2:size(y, 1)
      copyy[cor+1, i] = size(x,2)/10 - y[cor, i]
      copyy[cor, i] = y[cor+1, i]
    end
    for img in 1:size(x, 3)
      for o in 1:size_x
        copyx[:, size_x-(o-1), img, i] = x[o, :, img, i]
      end
    end
  end
  return copyx, copyy
end

"""
    flip_3D(x, y)

Takes 3D volumes in a 4D tensor and landmark data in 2D tensor and returns
the flipped (clockwise) volumes, aswell
as the coordinates for the flipped volumes.
"""
function flip_3D(x, y)
  copyx = zeros(Float32, size(x, 2),size(x, 1),size(x, 3),size(x, 4))
  copyy = deepcopy(y)
  inds = size(y, 2)
  size_x = size(x, 1)
  Threads.@threads for i in 1:inds
    for cor in 1:3:size(y, 1)
      copyy[cor+1, i] = size(x,2)/10 - y[cor, i]
      copyy[cor, i] = y[cor+1, i]
    end
    for o in 1:size_x
      copyx[:, size_x-(o-1), :, i] = x[o, :, :, i]
    end
  end
  return copyx, copyy
end

# """
#     jitter(x, y)
#
# Jitters around images based on their corresponding 2D landmarks, so that
# all landmarks and at least 8 pixels around them will still be inside
# the image.
# """
# function jitter(x, y)
#   copyx = zeros(Float32, size(x, 2),size(x, 1),size(x, 3),size(x, 4))
#   copyy = y
#   copyx = cat(x, copyx, dims=length(size(x)))
#   copyy = hcat(y, copyy)
#   inds = size(y, 2)
#   for i in 1:inds
#     max_x = 0
#     max_y = 0
#     for cor in 1:2:size(y,1)
#       if y[cor+1, i] > max_y
#         max_y = round(y[cor+1, i], digits=1)
#       end
#       if y[cor, i] > max_x
#         max_x = round(y[cor, i], digits=1)
#       end
#     end
#     max_x = max_x*10 + 8
#     max_y = max_y*10 + 8
#     minval = minimum(x[:,:,1,i])
#     if max_x >= size(x,1)
#       jitterx = 1
#     else
#       jitterx = rand(1:size(x,1)-floor(Int, max_x))
#       for o in 1:jitterx
#         copyx[o, :, 1, inds + i] .= minval
#       end
#     end
#     if max_y >= size(x,2)
#       jittery = 1
#     else
#       jittery = rand(1:size(x,2)-floor(Int, max_y))
#       for o in 1: jittery
#         copyx[:, o, 1, inds + i] .= minval
#       end
#     end
#     for o in jitterx:size(x,1)
#       copyx[o, jittery+1:end,1,inds+i] = x[(o-(jitterx-1)), 1:end-jittery,1,i]
#     end
#     for o in 1:2:size(y,1)
#       copyy[o,inds+i] = y[o,i] + jitterx/10
#       copyy[o+1,inds+i] = y[o+1,i] + jittery/10
#     end
#   end
#   return copyx, copyy
# end

"""
    jitter_3D(volumes, landmarks, padding)

Jitters around binarized volumes based on their corresponding x/y landmarks, so that
the relevant object (smaller voxel value) will still be fully inside the volume but
moved around randomly inside the volume.
"""
function jitter_3D(volumes, landmarks, padding)
  coordinates = to_3d_array(landmarks)
  out = deepcopy(volumes)
  Threads.@threads for ind in 1:size(landmarks, 2)
    filler = maximum(volumes[:,:,:,ind])
    size_x = size(volumes[:,:,:,ind], 1)
    size_y = size(volumes[:,:,:,ind], 2)
    size_z = size(volumes[:,:,:,ind], 3)
    min_x = max(0, minimum(coordinates[:,1,ind]) * 10 - padding)
    max_x = min(size_x, maximum(coordinates[:,1,ind]) * 10 + padding)
    min_y = max(0, minimum(coordinates[:,2,ind]) * 10 - padding)
    max_y = min(size_y, maximum(coordinates[:,2,ind]) * 10 + padding)
    min_z = max(0, minimum(coordinates[:,3,ind]) * 10 - padding)
    max_z = min(size_z, maximum(coordinates[:,3,ind]) * 10 + padding)
    jitter_x = rand(-floor(Int, min_x):(size_x-floor(Int, max_x)))
    jitter_y = rand(-floor(Int, min_y):(size_y-floor(Int, max_y)))
    jitter_z = rand(-floor(Int, min_z):(size_z-floor(Int, max_z)))
    out[:,:,:,ind] .= filler
    out[max(1, jitter_x+1):min(size_x, size_x+jitter_x), max(1, jitter_y+1):min(size_y, size_y+jitter_y),
      max(1, jitter_z+1):min(size_z, size_z+jitter_z), ind] .= volumes[max(1, -jitter_x+1):min(size_x, size_x-jitter_x),
      max(1, -jitter_y+1):min(size_y, size_y-jitter_y),
        max(1, -jitter_z+1):min(size_z, size_z-jitter_z), ind]
    coordinates[:,1,ind] .= coordinates[:,1,ind] .+ jitter_x/10
    coordinates[:,2,ind] .= coordinates[:,2,ind] .+ jitter_y/10
    coordinates[:,3,ind] .= coordinates[:,3,ind] .+ jitter_z/10
  end
  lms_out = to_2d_array(coordinates)
  return out, lms_out
end

"""
    rotate_2d(img, lms, deg)

Rotates an Image by deg degrees around its center in a counter clockwise direction.
The 2d landmarks (coordinates x individuals) will be adjusted to the rotated image.
Returns rotated image and adjusted landmarks.
"""
function rotate_2d(img, lms, deg)
  deg = deg*pi/180
  rotated = Images.imrotate(img, -deg)
  size_x = size(rotated, 1)
  size_y = size(rotated, 2)
  out = Images.imresize(rotated, (size(img, 1), size(img, 2)))
  n_points = floor(Int, length(lms)/2)
  coords = zeros(2,n_points)
  coords_out = zeros(n_points*2, 1)
  for i in 1:n_points
    coords[1,i] = lms[i*2-1]
    coords[2,i] = lms[i*2]
  end
  coords[1,:] = coords[1,:] .- (size(img,1)/2)/10
  coords[2,:] = coords[2,:] .- (size(img,2)/2)/10
  for i in 1:n_points
    coords_out[i*2-1] = (coords[1,i]*cos(deg) - coords[2,i]*sin(deg) + (size_x/2)/10) * size(img,1)/size_x
    coords_out[i*2] = (coords[1,i]*sin(deg) + coords[2,i]*cos(deg) + (size_y/2)/10) * size(img,2)/size_y
  end
  return out, coords_out
end

"""
    rotate_images(img, lms, deg)

Takes a 3d tensor [res1 x res1 x n] with n images and rotates all of them
in a counterclockwise direction around their center by deg degrees. Will adjust the 2d coordinates
of the landmark array [coords x n]. Returns rotated images and adjusted landmarks.
"""
function rotate_images(imgs, lms, deg)
  n_inds = size(imgs, 4)
  out = deepcopy(imgs)
  lms_out = deepcopy(lms)
  for i in 1:n_inds
    for img in 1:size(imgs, 3)
      filler = maximum(imgs[:,:,img,i])
      if img == 1
        rotated, rotated_lms = rotate_2d(imgs[:,:,img,i], lms[:,i], deg)
        lms_out[:,i:i] .= rotated_lms
        rotated[findall(x->isnan(x)==true, rotated)] .= filler
      else
        rotated_img = Images.imrotate(imgs[:,:,img,i], -deg*pi/180)
        rotated = Images.imresize(rotated_img, (size(imgs, 1), size(imgs, 2)))
        rotated[findall(x->isnan(x)==true, rotated)] .= filler
      end
      out[:,:,img,i] .= rotated

    end
  end
  return out, lms_out
end

"""
    rotate_volumes(vols, lms, deg)

Takes a 4d tensor [res1 x res2 x res3 x n] with n volumes and rotates all of them
around their center by deg degrees. The rotation is along the z-axis, so the z-coordinates
will not be affected. x- and y coordinates of the landmark array [coords x n] will be adjusted.
Returns rotated volumes and adjusted landmarks.
"""
function rotate_volumes(vols, lms, deg)
  n_inds = size(lms, 2)
  n_points = floor(Int, size(lms, 1)/3)
  x_y_only = zeros(n_points*2, n_inds)
  for i in 1:n_points
    x_y_only[i*2-1:i*2,:] .= lms[i*3-2:i*3-1,:]
  end
  x_y_rotated = deepcopy(x_y_only)
  out = deepcopy(vols)
  out_lms = deepcopy(lms)
  for i in 1:n_inds
    filler = maximum(vols[:,:,:,i])
    for img in 1:size(vols, 3)
      if img == 1
        rotated, rotated_lms = rotate_2d(vols[:,:,img,i], x_y_only[:,i], deg)
        rotated[findall(x->isnan(x)==true, rotated)] .= filler
        out[:,:,img,i] .= rotated
        x_y_rotated[:,i] .= rotated_lms[:,1]
      else
        rotated_img = Images.imrotate(vols[:,:,img,i], -deg*pi/180)
        rotated = Images.imresize(rotated_img, (size(vols, 1), size(vols, 2)))
        rotated[findall(x->isnan(x)==true, rotated)] .= filler
        out[:,:,img,i] .= rotated
      end
    end
  end
  for i in 1:n_points
    out_lms[i*3-2:i*3-1,:] .= x_y_rotated[i*2-1:i*2,:]
  end
  return out, out_lms
end
