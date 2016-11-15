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
    require 'fileutils'

    @log = []

    class << self
        attr_reader :log
    end

module RadUtils

  # Define all module instance variables, constants and attribute accessors
  UNIT = 0.0254   ## inch (SU native unit) to meters (Radiance)
  TRIANGULATE = false

    def writeLog(msg, loglevel=0)
        prefix = "  " * (loglevel)
        line = "%s %s" % [prefix, msg]
        begin
            Sketchup.set_status_text(line.strip())
        rescue
        end
        SU2rad.log.push(line)
    end
    module_function :writeLog

    # fixme used
    # Create file and write +text+ to +filename+ in a safe way
    def createFile(filename, text, comments=true, encoding=nil)
        path = File.dirname(filename)
        #createDirectory(path)
        FileUtils.mkdir_p(path)
        if not FileTest.directory?(path)
            return false
        end
        begin
            if encoding.nil?
              f = File.new(filename, 'w')
            else
              f = File.new(filename, 'w', encoding: encoding)
            end
            if comments
                comment = "# #{filename} file is automatically generated.\n"
                comment += "# Created: #{f.mtime}\n\n"
                f.write(comment)
            end
            f.write(text)
            f.close()
            #puts "created file '%s'" % filename
        rescue
            puts "Error: could not create file '%s': %s" % [filename, $!.message]
            return false
        end
        return true
    end
    module_function :createFile

    # Remove spaces and other funny chars from string +s+
    def remove_spaces(s)
        return s.gsub(/\s+/, '_').gsub(/\W/, '')
    end
    module_function :remove_spaces

    # fixme used
    # Clean path +path+ to be in accordance with Ruby syntax and
    # current File::SEPARATOR
    def cleanPath(path)
        if path.slice(-1,1) == File::SEPARATOR
            path = path.slice(0,path.length-1)
        end
    path = path.gsub(/\\/, File::SEPARATOR)
        return path
    end
    module_function :cleanPath

end
end
end
