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
  if defined?(Sketchup)
    Sketchup.require(File.join(currentDir, "material2"))
  else
    require(File.join(currentDir, "material2"))
  end

  class MaterialLibrarySimple
    attr_reader :name, :materials, :description, :path

    def initialize(path=nil)
      @description = ''
      @materials = []
      @_materials_hash = {}
      @_aliase_to_id = {}
      @path = path
      load_file
    end

    def load_file
      return if not @path
      return if @path == ''
      @materials = []
      @_materials_hash = {}
      @_aliase_to_id = {}
      begin
        if FileTest.file? @path
          content = File.read(@path)
        end
      rescue
        content = nil
      end
      load_content(content)
    end

    def load_content(content)
      return if !content
      begin
        @materials = []
        @_materials_hash = {}
        result = RadianceParser.new(content)
        @description = result.description
        @materials = result.materials
        _update_hash
      rescue
        return
      end
    end

    def _update_hash
      # for hash access to materials
      @_materials_hash = {}
      @_aliase_to_id = {}
      @materials.each { |m|
        @_materials_hash[m.identifier] = m
        m.aliases.each { |a_name|
          @_aliase_to_id[a_name] = m.identifier
        }
      }
    end

    def set_path new_path
      @path = new_path
    end

    def set_description description
      @description = description.gsub(/^# ?/, '').gsub(/^/, '# ').strip + "\n"
    end

    def description_unarmored
      return @description.gsub(/^# ?/, '')
    end

    def get_full_content_without_aliases
      paragraphs = []
      paragraphs.push @description
      @materials.each { |material| paragraphs.push material.commented_definition }
      return paragraphs.join("\n") + "\n"
    end

    def get_minimal_content
      paragraphs = []
      @materials.each { |material|
        paragraphs.push material.definition_single_line
        }
      paragraphs.sort!
      return paragraphs.join("\n") + "\n"
    end

    def get_full_content
      paragraphs = []
      paragraphs.push @description
      @materials.each { |material|
        paragraphs.push material.commented_definition
        aliases = material.aliases_text
        paragraphs.push aliases if aliases.length > 0
      }
      return paragraphs.join("\n") + "\n"
    end

    def _dump content
      begin
        File.open(@path, 'w') { |file| file.write(content) }
        return true
      rescue
        return false
      end
    end

    def dump_file
      return false if !@path
      _dump get_full_content
    end

    def dump_file_without_aliases
      return false if !@path
      _dump get_full_content_without_aliases
    end

    def dump_file_minimal
      return false if !@path
      _dump get_minimal_content
    end

    def length
      return @materials.length
    end

    # Update material definition
    #
    # If material is in the list update its value
    # If it isn't in the list add new material and set its value
    #
    #   * +material+ - #Material object
    def update_material(material)
      if get(material.identifier) == nil
        @materials.push material
      else
        new_materials = []
        identifier = material.identifier
        @materials.each { |current_mat|
          if current_mat.identifier == identifier
            new_materials.push material
          else
            new_materials.push current_mat
          end
        }
        @materials = new_materials
      end
      _update_hash
    end

    # Returns material object based on its name
    #
    #   * +mname+ (string) - material name
    def get(mname)
      return nil if !mname
      radname = mname.gsub(/\s+/, '_')
      return @_materials_hash[radname]
    end

    # get the real material by an alias name
    # usage could be :
    #   material = get(name) || get_alias(name)
    def get_alias(a_name)
      return nil if !a_name
      radname = a_name.gsub(/\s+/, '_')
      identifier = @_aliase_to_id[radname]
      return nil if !identifier
      return @_materials_hash[identifier]
    end

    #Return ordered list of all material names in library
    def get_identifiers
      return @materials.collect { |m| m.identifier }
    end

    # sort the library by identifier
    def sort
      names = get_identifiers
      names.sort!
      reorder_materials names
    end

    #reorder list of materials based on ordered list of names
    def reorder_materials(identifier_list)
      new_materials = []
      stored = {}
      identifier_list.each { |identifier|
        next if stored.key? identifier
        material = get(identifier)
        if material
          stored[identifier] = true
          new_materials.push material
          next
        end
      }
      # security if some missing : add to end
      @materials.each { |current_mat|
        next if stored.key? current_mat.identifier
        new_materials.push current_mat
        }
      @materials = new_materials
      _update_hash
    end
    #
    ## For input material returns definition containing all required materials
    ## and final material definition
    ## to be completely defined
    ##
    ##   * +mname+ (string) - material name
    #def getMaterialWithDependencies(mname)
    #  radMat = get(mname)
    #  if not radMat
    #    return false
    #  end
    #  mdef = ""
    #  while radMat
    #    mdef = "%s\n%s" % [radMat.getText(), mdef]
    #    radMat = get(radMat.required)
    #  end
    #  return mdef.strip()
    #end

    # Checks recursively if modifiers required for material are defined
    #
    #   * +m+ (string) - material object
    # FIXME: would need test that material is in library too...
    def is_defined?(material)
      req = material.required
      return true if req == 'void'
      needed_material = get(req)
      return false if !needed_material
      return is_defined? needed_material
    end

    #Return list of required materials names for current material
    #
    #   * +m+ (string) - material object
    def get_required_list(material)
      req = material.required
      list = []
      while req != 'void'
        list.push req
        next_material = get(req)
        break if !next_material
        req = next_material.required
      end
      return list
    end

    #Remove material from library based on its name
    #
    #return true/false
    def remove_material(identifier)
      radname = identifier.gsub(/\s+/, '_')
      if !get(radname)
        return false
      end
      new_materials = []
      @materials.each { |current_mat|
          if current_mat.identifier == radname
            next
          end
          new_materials.push current_mat
      }
      @materials = new_materials
      _update_hash
      return true
    end

    # Gets reflection and transmitance values for the material from library
    #
    #   * +mname+ (string) - material name
    def get_reflectance(mname)
      material = get(mname)
      return material.reflectance if material
      return nil
    end

    def get_transmittance(mname)
      material = get(mname)
      return material.transmittance if material
      return nil
    end

    # Gets material textual definition
    #
    #   * +mname+ (string) - material name
    def get_definition(mname)
      material = get(mname)
      return material.definition if material
      return nil
    end

    # Gets material comment if defined
    #
    #   * +mname+ (string) - material name
    def get_comment(mname)
      material = get(mname)
      return material.comment if material
      return nil
    end

    def get_comment_unarmored(mname)
      material = get(mname)
      return material.comment_unarmored if material
      return nil
    end

    def get_commented_definition(mname)
      material = get(mname)
      return material.commented_definition if material
      return nil
    end

    def get_aliases_text(mname)
      material = get(mname)
      return material.aliases_text if material
      return nil
    end

    # Gets material float parameters
    #
    #   * +mname+ (string) - material name
    def get_float_param(mname)
      material = get(mname)
      return material.float_param if material
      return nil
    end

    # Gets material string parameters
    #
    #   * +mname+ (string) - material name
    def get_str_param(mname)
      material = get(mname)
      return material.str_param if material
      return nil
    end

    # Gets material type
    #
    #   * +mname+ (string) - material name
    def get_type(mname)
      material = get(mname)
      return material.type if material
      return nil
    end

    # Returns flag whether material is glazing or not
    #
    #   * +mname+ (string) - material name
    def glazing?(mname)
      material = get(mname)
      return material.glazing if material
      return nil
    end

    # Returns flag whether material is grey or not
    #
    #   * +mname+ (string) - material name
    def grey?(mname)
      material = get(mname)
      return material.grey if material
      return nil
    end

    # Returns flag whether material is translucent or not
    #
    #   * +mname+ (string) - material name
    def translucent?(mname)
      material = get(mname)
      return material.translucent if material
      return nil
    end
  end


  class RadianceParser
    attr_reader :description, :materials

    def initialize(content)
      @description = nil
      @materials = nil
      @content = content
      @aliases = {}
      parse_into_blocks
      parse_blocks
      insert_aliases
    end

    def new_element
      return {
          'comment' => [],
          'info' => []
      }
    end

    def parse_into_blocks
      @started = false
      @command_continue = false
      @blocks = []
      @current = new_element
      @content.lines { |line|
        if line.start_with?('#')
            got_comment line
            next
        end
        if @command_continue || line.start_with?('!')
            got_command line
            next
        end
        if line =~ /^\s*$/
             got_empty line
             next
        end
        got_info line
      }
    end

    def got_command line
      command = line.chomp
      @command_continue = command[-1] == '\\'
      # drop command line
    end

    def got_comment line
      comment = line.chomp
      @current['comment'].push(comment)
    end

    def got_empty line
      return if @started
      # maybe splitting between file comment and first material comment
      if @current['comment'].length > 0
        # already got comments, so separe them from following ones
        @blocks.push @current
        @current = new_element
      end
    end

    def got_info line
      # expecting not a ! command... or bad format
      @started = true
      @current['info'] += line.chomp.split
      #check info complete
      if @current['info'].length < 4
        # not enough items
        return
      end
      return if is_an_alias?
      if check_complete_primitive?
        @blocks.push @current
        @current = new_element
      end
    end

    def is_an_alias?
      info = @current['info']
      if info.length == 4 and info[1] == 'alias'
        alias_name = info[2]
        identifier = info[3]
        alist = @aliases[identifier] || []
        alist.push alias_name
        @aliases[identifier] = alist
        @current = new_element
        return true
      end
      return false
    end

    def check_complete_primitive?
      info = @current['info']
      return false if info.length < 6  # not enough parts
      #modifier = info[0]
      #type = info[1]
      #identifier = info[2]
      nb_str = info[3].to_i
      #zero_position = 4 + nb_str
      nb_float_position = 5 + nb_str
      #zero = info[zero_position]
      nb_float = info[nb_float_position].to_i
      expected_length = 6 + nb_str + nb_float
      return true if info.length >= expected_length
      return false
    end

    def parse_blocks
      headers = []
      @materials = []
      @blocks.each { |block|
        comment = block['comment']
        info = block['info']
        if info.length == 0 && comment.length > 0
          # add to initial comment with blnk line before
          headers.push comment.join("\n")
          next
        end
        text = comment.join("\n") + "\n" + info.join(" ")
        material = Material2.new(text)
        materials.push material if material.valid?
      }
      @description = headers.join("\n\n") + "\n"
    end

    def insert_aliases
      seen = {}
      @materials.each { |m|
        a_list = @aliases[m.identifier]
        next if !a_list
        a_list.each { |a_name|
          # drop bad duplicate alias:
          next if seen.key? a_name
          m.add_alias(a_name)
          seen[a_name] = true
        }
      }
    end
  end

end
end
