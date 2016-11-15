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

# Create radiance view file based on Sketchup camera position
class SketchupView

    attr_reader :name
    attr_reader :selected
    attr_reader :current
    attr_writer :selected

    include SU2rad::RadUtils

    # Initialize parameters required for Radiance view definition
    def initialize (name, current=false, filename="")
        @name = name
        @current = current
        @filename = filename
        @_fitted = false
        @page = nil
        @pageChanged = false
        @selected = false
        if current == true
            @selected = true
        end
        @updatePageView = false
        @vt = "v"
        @vp = [0,0,1]
        @vd = [0,1,0]
        @vu = [0,0,1]
        @va = 0.0
        @vo = 0.0
        @vv = 60.0
        @vh = 60.0
        @hFovPersp = 60.0
        @vFovPersp = 60.0
        @hFovParra = 60.0
        @vFovParra = 60.0
    end

    def applyToPage
        begin
            if @page
                camera = @page.camera
            else
                camera = Sketchup.active_model.active_view.camera
            end
            eye = [@vp[0]/UNIT, @vp[1]/UNIT, @vp[2]/UNIT]
            target = [eye[0]+@vd[0],eye[1]+@vd[1],eye[2]+@vd[2]]
            camera.set(eye, target, @vu)
            fitFoV(camera)
            Sketchup.active_model.active_view.show_frame()
        rescue => e
            puts "Error in view.applyToPage(view='#{@name}'):\n%s\n\n%s\n"\
              % [$!.message,e.backtrace.join("\n")]
            return false
        end
    end

    def _compareSetting(k,v)
        begin
            oldValue = eval("@%s" % k)
        rescue => e
            puts "Error getting attribute '%s': %s" % [k, $!.message]
            return false
        end
        if k == 'vt'
            if oldValue == 'l' and v != 'l'
                return true
            elsif oldValue == 'v' and v == 'l'
                return true
            else
                return false
            end
        elsif (k == 'vp' || k == 'vd' || k == 'vu')
            begin
                oldVect = "%.3f %.3f %.3f" % oldValue
                newVect = "%.3f %.3f %.3f" % v
                return (oldVect != newVect)
            rescue => e
                puts "Error while converting to vector: %s\n%s\n\n" \
                  % [$!.message, e.backtrace.join("\n")]
                return false
            end
        else
            ## all other setting are not comparable
            return false
        end
    end

    def createViewFile
        name = remove_spaces(@name)
        viewpath = File.join("views", "%s.vf" % name)
        #print "viewfile: #{@filename}\n"
        if not createFile(@filename, getViewLine(),false)
            msg = "Error: could not create view file '#{@filename}'"
            return "## %s" % msg
        elsif @selected == true
            return "view=  #{name} -vf #{viewpath}"
        else
            return "# view=  #{name} -vf #{viewpath}"
        end
    end

    def fitFoV(camera)
        ## calculate page camera fov to fit view
        ## set flag to avoid export of modified fov
        @_fitted = true
        imgW = Sketchup.active_model.active_view.vpwidth.to_f
        imgH = Sketchup.active_model.active_view.vpheight.to_f
        asp_c = imgW/imgH
        asp_v = @vh/@vv

        if @vt == 'l'
            camera.perspective = false
            if asp_c > asp_v
                camera.height = @vv/UNIT
            else
                camera.height = (@vh/asp_c)/UNIT
            end
        else
            camera.perspective = true
            if asp_c > asp_v
                camera.fov = @vv
            elsif asp_c > 1.0
                camera.fov = _getFoVAngle(@vh, imgW, imgH)
            else
                camera.fov = @vh
            end
        end
    end

    def _getSettingsDict
        dict = {'name' => @name, 'selected' => @selected,
                'current' => @current, 'pageChanged' => @pageChanged,
                'vt' => @vt, 'vp' => @vp, 'vd' => @vd, 'vu' => @vu,
                'vo' => @vo, 'va' => @va}
        if not @_fitted
            dict['vv'] = @vv
            dict['vh'] = @vh
        end
        if @page
            overrides = @page.attribute_dictionary('SU2RAD_VIEW')
            if overrides
                dict['overrides'] = overrides.keys()
            end
        end
        return dict
    end

    # INFO: theses function are necessary for DeluminaeLightSimulator
    def getViewPosition()
      return @vp
    end

    def getViewUp()
      return @vu
    end


    def getViewDirection()
      return @vd
    end

    def getViewTarget()
      return @vTarget
    end

    def getVerticalFov()
      return @vv
    end

    def getHorizontalFov()
      return @vh
    end


    def DLSHorizontalFovPerpective()
      return @hFovPersp
    end

    def DLSVerticalFovPerpective()
      return @vFovPersp
    end

    def DLSHorizontalFovParrallele()
      return @hFovParra
    end

    def DLSVerticalFovParrallele()
      return @vFovParra
    end

    def getName()
      return @name
    end

    def GetCamera()
      return @camera
    end


    def getViewLine
        text = "rvu -vt#{@vt}"
        text +=   " -vp %f %f %f" % @vp
        text +=   " -vd %f %f %f" % @vd
        text +=   " -vu %f %f %f" % @vu
        text +=  " -vv #{@vv} -vh #{@vh} -vo #{@vo} -va #{@va}"
        return text
    end

    def _setFloatValue(k, v)
        begin
            oldValue = eval("@%s" % k)
            if oldValue != v
                eval("@%s = %s" % [k,v])
                puts "View '%s': new value for '%s' = '%s'" % [@name,k,v]
                if k == 'vv' || k == 'vh'
                    @updatePageView = true
                end
            end
            return true
        rescue
            puts "Error view '%s': value for '%s' not a float value [v='%s']" % [@name,k,v]
            return false
        end
    end

    def setPage(page)
        ## update view from settings in page attribute_dict
        @page = page
        begin
            d = @page.attribute_dictionary('SU2RAD_VIEW')
        rescue => e
            puts "Error getting attributes:\n%s\n\n%s\n" % [$!.message,e.backtrace.join("\n")]
        end
        if d != nil
            dict = Hash.new()
            d.each_pair { |k,v|
                dict[k] = v
                @pageChanged = _compareSetting(k,v) || @pageChanged
            }
            if dict.has_key?('name')
                dict.delete('name')
            end
            if @current
                dict['selected'] = true
            end
            update(dict, false)
            @pageChanged = false #XXX
        end
    end

    def _setViewVector(k, value)
        ## parse v as x,y,z tripple
        if value.class == Array
            if value.length != 3
                puts "Error view '%s': value for '%s' not a vector [v='%s']" % [@name,k,v.to_s]
                return false
            else
                vect = "[%.3f,%.3f,%.3f]" % value
            end
        else
            begin
                if value.index(',') != nil
                    x,y,z = value.split(',').collect { |v| v.to_f }
                else
                    x,y,z = value.split().collect { |v| v.to_f }
                end
                vect = "[%.3f,%.3f,%.3f]" % [x,y,z]
            rescue
                puts "Error view '%s': value for '%s' not a vector [v='%s']" % [@name,k,v]
                return false
            end
        end
        oldVect = "[%.3f,%.3f,%.3f]" % eval("@%s" % k)
        if oldVect != vect
            eval("@%s = %s" % [k,vect])
            puts "View '%s': new value for '%s' = '%s'" % [@name,k,vect]
            @updatePageView = true
        end
        return true
    end

    def _setViewOption(k,v)
        ## set bool or string value
        if v == 'true'
            v = true
        elsif v == 'false'
            v = false
        end
        oldValue = eval("@%s" % k)
        if v != oldValue
            puts "View '%s': new value for '%s' = '%s'" % [@name,k,v]
            if k == 'vt'
                @updatePageView = true
            end
            if (v == 'true' || v == 'false')
                eval("@%s = %s" % [k,v])
            elsif (v.class == TrueClass || v.class == FalseClass)
                eval("@%s = %s" % [k,v])
            else
                eval("@%s = '%s'" % [k,v])
            end
        end
        return true
    end

    def setViewParameters(camera)
        @camera = camera
        ## set params from camera
        @vp = [camera.eye.x*UNIT, camera.eye.y*UNIT, camera.eye.z*UNIT]
        @vTarget = [camera.target.x*UNIT, camera.target.y*UNIT, camera.target.z*UNIT]
        @vd = [camera.zaxis.x, camera.zaxis.y, camera.zaxis.z]
        @vu = [camera.up.x, camera.up.y, camera.up.z]
        imgW = Sketchup.active_model.active_view.vpwidth.to_f
        imgH = Sketchup.active_model.active_view.vpheight.to_f
        aspect = imgW/imgH

        if aspect > 1.0
          @vFovPersp = camera.fov
          @hFovPersp = _getFoVAngle(@vFovPersp, imgH, imgW)
        else
          @hFovPersp = camera.fov
          @vFovPersp = _getFoVAngle(@hFovPersp, imgH, imgW)
        end
        @vFovParra = camera.height * UNIT.to_f
        @hFovParra = @vFovParra*aspect


        if camera.perspective?
            @vt = 'v'
            @vv = @vFovPersp
            @vh = @hFovPersp
        else
            @vt = 'l'
            @vv = @vFovParrra
            @vh = @hFovParrra
        end
    end

    def storeSettings(overrides={})
        if not @page
            return
        end
        begin
            @page.delete_attribute('SU2RAD_VIEW')
        rescue => e
            puts "Error deleting attribute_dict 'SU2RAD_VIEW':\n%s\n\n%s\n" % [$!.message,e.backtrace.join("\n")]
        end
        if overrides == {}
            overrides = {'selected'=>true,'vt'=>true, 'vo'=>true, 'va'=>true}
        end
        begin
            d = _getSettingsDict()
            d.each_pair { |k,v|
                if overrides.has_key?(k)
                    @page.set_attribute('SU2RAD_VIEW', k, v)
                end
            }
        rescue => e
            puts "Error setting attributes:\n%s\n\n%s\n" % [$!.message,e.backtrace.join("\n")]
            return false
        end
    end

    def _getFoVAngle(ang1, side1, side2)
        ang1_rad = ang1*Math::PI/180.0
        dist = side1 / (2.0*Math::tan(ang1_rad/2.0))
        ang2_rad = 2 * Math::atan2(side2/(2*dist), 1)
        ang2 = (ang2_rad*180.0)/Math::PI
        return ang2
    end

    # def toJSON
        # json = toStringJSON(_getSettingsDict())
        # return json
    # end

    def update(dict, store=true)
        overrides = {'vt'=>true, 'vo'=>true, 'va'=>true}
        if dict.has_key?('vt')
            if _setViewOption('vt', dict['vt']) == true
                overrides['vt'] = true
            end
            dict.delete('vt')
        end
        dict.each_pair { |k,v|
            begin
                if (k == 'vp' || k == 'vd' || k == 'vu')
                    if _setViewVector(k, v) == true
                        overrides[k] = true
                    end
                elsif (k == 'vv' || k == 'vh' || k == 'vo' || k == 'va')
                    if _setFloatValue(k, v) == true
                        overrides[k] = true
                    end
                else
                    _setViewOption(k, v)
                end
            rescue
                puts "view '%s' update(key='%s',v='%s'):\n%s" % [@name,k,v,$!.message]
            end
        }
        applyToPage()
        if store == true
            overrides['selected'] = @selected
            storeSettings(overrides)
        end
    end

end


# Detects all views (scenes) defined in Sketchup model and extracts
# camera parameters for each scene.
# If no scenes defined extracts current view and manes it 'unnamed_view'
# Creates radiance view files based on extracted data
class SketchupViewsList

    include SU2rad::RadUtils

    def initialize(output_dir = "")
        @camera_view_name = "_Sketchup Camera View_"
        @output_dir = output_dir
        @_views = {}
        initViews()
    end

    # INFO: used by DaylightSimulator
    def GetViews()
      return @_views
    end

    ## Creates radiance view files based on extracted data
    def getViewLines
        lines = @_views.values.collect { |v| v.createViewFile() }
        return lines.join("\n")
    end


    # Detects all views (scenes) defined in Sketchup model and extracts
    # camera parameters for each scene.
    # If no scenes defined extracts current view and manes it 'unnamed_view'
    def initViews
      pages = Sketchup.active_model.pages
      # INFO: add default camera as a possible view even if other views exist
      filename = File.join(@output_dir,"views", @camera_view_name + ".vf")
      view = SketchupView.new(@camera_view_name, true,filename)
      view.setViewParameters(Sketchup.active_model.active_view.camera)
      @_views[view.name] = view

      pages.each { |page|
        viewname = page.name
        filename = File.join(@output_dir,"views","#{viewname}.vf")
        if page == pages.selected_page
            view = SketchupView.new(viewname, true,filename)
            view.setViewParameters(page.camera)
            view.setPage(page)
            @_views[view.name] = view
        elsif page.use_camera? == true
            view = SketchupView.new(viewname,false,filename)
            view.setViewParameters(page.camera)
            view.setPage(page)
            @_views[view.name] = view
        end
      }
    end

end

end
end
