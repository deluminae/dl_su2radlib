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

  @inComponent = [] #array with flags whether current entity is in a component or not
  @geometryHash = {} #keys are material/layer names and values are list of Radiance polygon definition for the materials
  @globalTrans = nil # current transformation for exporting polygon to Radiance - to be able t oget correct absolute coordinates

  class << self
    attr_accessor :inComponent
    attr_accessor :geometryHash
    attr_accessor :globalTrans
  end

class ExportBase

  #@@name_count = {}  # unused
  #@@name_count.default = 0

  include SU2rad::RadUtils

  def initLog
    if not SU2rad.log
      SU2rad.log = []
    end
  end

  # Check if entity is visible or hiden. Returns boolean value
  #
  #   * +e+ - Entity object
  def isVisible(e)
    # entities on Layer0 inherit their visibility from groups or
    # components that containt them
    if SU2rad.inComponent[-1] == true && e.layer.name == 'Layer0'
      return true
    elsif e.hidden? ## hidden? method from Sketchup API
      return false
    elsif not e.layer.visible?
      return false
    end
    return true
  end

  # For each entity into input list, drills into group/component hierarchy
  # and recursively adds faces to the faces array
  #
  #   * +entity_list+ - list of entities to explore
  #   * +parenttrans+ - transformation that should be considered
  #   during export (if entity is in component or group)
  def exportByGroup(entity_list, parenttrans, instance=false, exportBy="layers")
    #puts "ExportByGroup: exportBy = #{exportBy}"
    #references = [] # unused
    faces = []
    # this drills into group/component hierarchy and recursively
    # adds faces to the faces array
    entity_list.each { |e|
      #skip entities from special layers or with special
      # materials starting with '_dl_'
      if exportBy == "layers" && e.layer.name.index('_dl_') == 0
        next
      elsif exportBy == "materials" && e.material !=nil && e.material.name.index('_dl_') == 0
        next
      end
      #export other layers: geometry and reference lines
      if e.class == Sketchup::Group
        ## continues to next entity if entity is hidden
        if not isVisible(e) then next end

        rg = RadianceGroup.new(e)
        #ref = rg.export(parenttrans)
        rg.export(parenttrans,exportBy)
        #references.push(ref)
      elsif e.class == Sketchup::ComponentInstance
        ## continues to next entity if entity is hidden
        if not isVisible(e) then next end

        rg = RadianceComponent.new(e)
        rg.export(parenttrans,exportBy)
      elsif e.class == Sketchup::Face
        if instance == false
          if not isVisible(e)
            next
          end
        end
        faces.push(e)
      elsif e.class == Sketchup::Edge
        next
      elsif e.class == Sketchup::ConstructionPoint  ## added for sunexposure
        next
      elsif e.class == Sketchup::Text  ## added for sunexposure
        next
      else
        #writeLog(
        #  "WARNING: Can't export entity of type '%s'!\n" % e.class)
        next
      end
    }
    #faces_text = '' # unused
    #numpoints = [] # unused
    faces.each { |f|
      rp = RadiancePolygon.new(f,exportBy)
      rp.getText(parenttrans)
    }

    ## stats message
    #writeLog(
    #  "exported entities [refs=%d, faces=%d]" % [references.length, faces.length], 1)
  end

  def point_to_vector(p)
    Geom::Vector3d.new(p.x,p.y,p.z)
  end

  #def getUniqueName(pattern="")
  #  if pattern == "" || pattern == nil
  #    pattern = "group"
  #  end
  #  pattern = remove_spaces(pattern)
  #  count = @@name_count += 1
  #  return "%s%02d" % [pattern, count]
  #end

  def showTransformation(trans)
    a = trans.to_a
    printf "  %5.2f  %5.2f  %5.2f  %5.2f\n" % a[0..3]
    printf "  %5.2f  %5.2f  %5.2f  %5.2f\n" % a[4..7]
    printf "  %5.2f  %5.2f  %5.2f  %5.2f\n" % a[8..11]
    printf "  %5.2f  %5.2f  %5.2f  %5.2f\n" \
      % [a[12]*UNIT, a[13]*UNIT, a[14]*UNIT, a[15]]
  end

end
end
end
