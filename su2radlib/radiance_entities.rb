# dl_su2radlib
# Copyright (c) 2016 De Luminae
# License : LGPL
# Authors: De Luminae team (http://www.deluminaelab.com)
#
# This file is part of dl_su2radlib library (Sketchup To Radiance Exporter
# library)
#
# dl_su2radlib is based on the su2rad (version 1.0 alpha) program, written by
# Thomas Bleicher and based on ogre_export by Kojack
#
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public License
# as published by the Free Software Foundation; either version 2 of
# the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this program; if not, write to the
# Free Software Foundation, Inc., 59 Temple
# Place - Suite 330, Boston, MA 02111-1307, USA, or go to
# http://www.gnu.org/copyleft/lesser.txt.

module DL
module SU2rad
    currentDir = File.dirname(__FILE__).force_encoding('UTF-8')
    Sketchup.require(File.join(currentDir, "rad_utils"))
    Sketchup.require(File.join(currentDir, "exportbase"))

# Export entities from Sketchup group to Radiance primitives
class RadianceGroup < ExportBase

    def initialize(entity)
        @entity = entity
        #writeLog("RadGroup: '%s'" % entity.name)
    end

    #Export Sketchup group entity to Radiance
    #
    # param @exportBy{"layers", "materials"} - flag that defines whether model
    #   will be exported by Sketchup layers or materials. Default is "layers"
    def export(parenttrans, exportBy="layers")
        # @entity should be a Sketchup group;
        # this retrieves the entities from that group
        entities = @entity.entities
        # creates unique name for group in case of duplicates
        # getUniqueName(@entity.name)  # unused
        parenttrans *= @entity.transformation
        #$nameContext.push(name)
        oldglobal = SU2rad.globalTrans
        SU2rad.globalTrans *= @entity.transformation
        ref = exportByGroup(entities, parenttrans, false, exportBy)
        SU2rad.globalTrans = oldglobal
        #$nameContext.pop()
        return ref
    end
end

# Export entities from Sketchup component to Radiance primitives
class RadianceComponent < ExportBase

    #attr_reader :replacement, :iesdata, :lampMF, :lampType

    def initialize(entity)
        @entity = entity
    end

    # Export Sketchup component entity to Radiance
    #
    # param @exportBy{"layers", "materials"} - flag that defines whether model
    #   will be exported by Sketchup layers or materials. Default is "layers"
    def export(parenttrans, exportBy="layers")
        entities = @entity.definition.entities
        #defname = getComponentName(@entity)
        # getUniqueName(@entity.name) # unused

        #$nameContext.push(iname) ## use instance name for file

        #showTransformation(parenttrans)
        #showTransformation(@entity.transformation)
        parenttrans *= @entity.transformation
        #showTransformation(parenttrans)

        oldglobal = SU2rad.globalTrans
        SU2rad.globalTrans *= @entity.transformation
        SU2rad.inComponent.push(true)
        exportByGroup(entities, parenttrans, false, exportBy)
        SU2rad.inComponent.pop()
        SU2rad.globalTrans = oldglobal
        #$nameContext.pop()
    end
end

# Export single face from Sketchup model to Radiance polygon primitive
# Exports correctly both faces with and without holes
class RadiancePolygon < ExportBase

    attr_reader :material, :layer
    @@id_count = 0

    #Initialize face that should be exported to Radiance
    #
    #param @exportBy={"layers", "materials"} - flag that defines whether model
    #   will be exported by Sketchup layers or materials. Default is "layers"
    def initialize(face, exportBy="layers")
        unless face
          #puts "Face not defined for RadiancePolygon"
          return
        end
        @face = face
        @layer = face.layer
        #puts "RadiancePolygon: exportBy = #{exportBy}"
        if exportBy == "layers"
            @material = face.layer.name
        else
            if face.material != nil
                @material = face.material.name
            elsif face.back_material != nil
                @material = face.back_material.name
                #puts "Warning: Face #{face} don't have front material "\
                #  "defined, back material will be used for export."
            else
                @material = "default_sketchup_material"
                #puts "Warning: Face #{face} don't have material "\
                #  "defined, default material will be used."
            end
        end
        @verts = []
        @triangles = []
        #puts "RadiancePolygon: exportBy = #{exportBy} material name: #{@material}"


        # Compose array of face vertices from vertices in outer loop
        # and in inside loops (holes in the face).
        # In Sketchup, a loop is a chain of edges describing the
        # boundary of a face. Each face has one outer loop,
        # and one loop for each hole
        face.loops.each { |l|
            if l.outer? == true
                @verts = l.vertices
            end
        }
        face.loops.each { |l|
            if l.outer? == false ## this is for holes
                addLoop(l) ## see below
            end
        }
    end

    def getVertices()
        return @verts
    end

    def getIdCount()
        return @@id_count
    end

    def setIdCount(id_count)
        @@id_count = id_count
    end

    # Create hole in polygon
    # find centre of new loop
    # parameters:
    #   - l (Loop) - loop of vertices for the face
    def addLoop(l)
        c = getCentre(l)
        # find closest point and split outer loop
        idx_out  = getNearestPointIndex(c, @verts)
        near_out = @verts[idx_out].position
        verts1 = @verts[0..idx_out]
        # splits outer loop vertices into two sets delineated by
        # vertex closest to center of hole
        verts2 = @verts[idx_out, @verts.length]
        # insert vertices of loop in reverse order to create hole
        idx_in = getNearestPointIndex(near_out, l.vertices)
        verts_h = getHoleVertices(l, idx_in) ## returns array of Point3D objects describing hole
        @verts = verts1 + verts_h + verts2 ## inserts hole vertices between outer loop vertices, adding hole by basically tracing around it
    end

    # Create array of vertices for inner loop
    # parameters
    #   - l (Loop) - loop of vertices for the face
    #   - idx_in (integer) - index of point of face outer loop nearest to the loop l
    # return
    #   - array of vertices for the hole defined by loop and face nearest corner
    def getHoleVertices(l, idx_in)
        verts = l.vertices
        ## get normal for loop via cross product
        p0 = verts[idx_in].position
        if idx_in < (verts.length-1)
            p1 = verts[idx_in+1].position
        else
            p1 = verts[0].position
        end
        p2 = verts[idx_in-1].position
        v1 = Geom::Vector3d.new(p1-p0)
        v2 = Geom::Vector3d.new(p2-p0)
        normal = v2 * v1
        normal.normalize!
        ## if normal of face and hole point in same direction
        ## hole vertices must be reversed
        if normal == @face.normal
            reverse = true
        #else
        #    dot = normal % @face.normal # unused
        end
        ## rearrange verts to start at vertex closest to outer face
        verts1 = verts[0..idx_in]
        verts2 = verts[idx_in, verts.length]
        verts = verts2 + verts1
        if reverse == true
            verts = verts.reverse
        end
        return verts
    end

    # Get centre vertice of the loop
    # simply averages each cartesian coordinates
    # parameters
    #   - l (Loop) - loop of vertices for the face
    # returns:
    #   - centre point (Point3d object)
    #   - nil - if loop contains 0 vertices
    def getCentre(l)
        verts = l.vertices
        x_sum = 0
        y_sum = 0
        z_sum = 0
        verts.each { |v|
            x_sum += v.position.x
            y_sum += v.position.y
            z_sum += v.position.z
        }
        n = verts.length
        if n > 0
            return Geom::Point3d.new(x_sum/n, y_sum/n, z_sum/n)
        else
            return nil
        end
    end

    # Get index of nearest point in array verts to the input point p
    # parameters:
    #   - p (Point3d) - target points
    #   - verts (Array of Vertices)
    # return
    #   - integer index on nearest point
    def getNearestPointIndex(p, verts)
        dists = verts.collect { |v| p.distance(v.position) }
        min = dists.sort[0]
        idx = 0
        verts.each_index { |i|
            v = verts[i]
            if p.distance(v) == min
                idx = i
                break
            end
        }
        return idx
    end

    def getPolyMesh(trans=nil)
        polymesh = @face.mesh 7
        if trans != nil
            polymesh.transform! trans
        end
        return polymesh
    end

    # return Radaince polygon definition of exported face
    def getText(trans=nil)
        if TRIANGULATE
            if @triangles.length == 0
                writeLog("WARNING: no triangles found for polygon")
                return ""
            end
            text = ''
            count = 0
            @triangles.each { |points|
                text += getPolygon(points, count, trans)
                count += 1
            }
        else
            points = @verts.collect { |v| v.position }
            text = getPolygon(points, 0, trans)
        end
        return text
    end

    # Compose Radiance polygon definition and put it in hash
    # (to print later into file)
    # For each face define attribute with unique ID
    # if it doesn't exist yet.
    # +id = (rand()*10000000).to_i+
    def getPolygon(points, count, trans)
        #if trans is not nil than use it as transformation of points,
        #else use SU2rad.globaltrans
        if trans != nil
            worldpoints = points.collect { |p| p.transform(trans) }
        else
            worldpoints = points.collect { |p| p.transform(SU2rad.globaltrans) }
        end
        matname = @material

        # 12th April 2012 Marija: define unique ID for the face
        id = @face.get_attribute("DL_faceData", "id", 0)
        if id == 0
            id = @@id_count += 1
            @face.set_attribute("DL_faceData", "id", id)
        else
            id =id.to_i
        end

        poly = "\n%s polygon f_%d_%d\n" % [matname.gsub(/\s+/, '_'), id, count]
        poly += "0\n0\n%d\n" % [worldpoints.length * 3]
        worldpoints.each { |wp|
            poly += "    %f  %f  %f\n" \
              % [wp.x*UNIT, wp.y*UNIT, wp.z*UNIT]
        }
        if not SU2rad.geometryHash.has_key?(matname)
            SU2rad.geometryHash[matname] = []
            # writeLog("new material for 'by Layer': '#{matname}'")
        end
        SU2rad.geometryHash[matname].push(poly)
    end
end

end
end
