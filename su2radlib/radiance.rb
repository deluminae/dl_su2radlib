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

  Keywords_Geometry = {'bubble'   => true,   'cone' => true,   'cup' => true,
                   'cylinder' => true, 'instance' => true, 'polygon' => true,
                   'ring'   => true,   'sphere' => true,  'tube' => true}
  Keywords_Material = {'antimatter' => true, 'dielectric' => true,
                   'interface'  => true,    'glass' => true,
                   'glow'     => true,    'light' => true,
                   'metal'    => true,   'metal2' => true,
                   'mirror'   => true,     'mist' => true,
                   'prism1'   => true,   'prism2' => true,
                   'plastic'  => true,   'plastic2' => true,
                   'trans'    => true,   'trans2' => true}
  Keywords_Pattern  = {'BRTDfunc'   => true,
                   'brightfunc' => true, 'brightdata' => true,
                   'brighttext' => true, 'colorfunc'  => true,
                   'colordata' => true,  'colorpict' => true,
                   'colortext' => true,
                   'metfunc'  => true,  'metdata' => true,
                   'plasfunc'   => true,   'plasdata' => true,
                   'transfunc'  => true,  'transdata' => true,
                   'mixfunc'  => true,  'mixdata' => true,
                   'mixpict' => true, 'mixtext' => true,
                   'texfunc'  => true,  'texdata' => true}
  Keywords_Other  = {'void'  => true,  'alias' => true}
  Keywords_Source = {'illum' => true, 'source' => true, 'spotlight' => true}

  # Radiance material and its parameters
  #   * name - matrial name
  #   * comment - material drecriptio
  #   * defType - Radiance modifier
  #   * matType - Material type
  #   * text - text for Radiance definition
  #   * str_param - string parameters
  #   * float_param - float parameters
  #   * valid - Flag wether material definition is valid
  #   * required - Modifier required to be able to use this
  #   material (pattern/texture name or void)
  class Material

    attr_reader :name, :comment, :defType, :matType, :text, :rest, :valid, :required

    #initialize varialbes
    # +text+ - Radiance definition of single material
    def initialize(text, comment='')
      @name = ''
      comment ||= ''
      @comment ||= comment
      @defType = 'material'
      @matType = nil
      @required = 'void'
      @text = ''
      @rest = ''
      @_group = ''
      begin
        @valid = parseText(text)
      rescue => e
        printf "Error in text: '#{text}'\n"
        msg = "%s\n  %s" % [$!.message,e.backtrace.join("\n  ")]
        printf "\n#{msg}\n"
        @valid = false
      end
    end

    # returns material type
    def getType
      return @matType
    end

    # returns material type or group if material is glow or light material
    def getGroup
      if @_group != ''
        return @_group
      elsif @matType == 'light' || @matType == 'glow'
        return 'light'
      elsif @matType =~ /2\z/
        return $`
      else
        return @matType
      end
    end

    # returns material name
    def identifier()
      return @name
    end

    # Parses Radiance definition of the material, and extracts important parameters
    # Sets +valid+ variable value depending on parsing results
    # If parsing unsucessful - rested all instance varialbes
    def parseText(text)
      begin
        @valid = _parseText(text)
      rescue => e
        printf "\nError in text: '#{text}'\n"
        msg = "%s\n%s" % [$!.message,e.backtrace.join("\n")]
        printf "\n#{msg}\n"
        @valid = false
        @name = ''
        @text = ''
        @rest = text
        @matType = nil
      end
    end

    # Do actual parsing of the +text+ and sets pappropriate instance variables
    def _parseText(text)
      #defparts = [] # unused
      valid = false # flag wether definition is valid or not
      comment = []

      #remove comment lines from definition
      lines = text.split("\n")
      i = 0
      while lines[i].index("#")==0 do
        comment.push(lines[i])
        i += 1
        if i == lines.size
          return false
        end
      end
      if comment.length > 0
        @comment += comment.join("\n")
      end
      text_without_comments = lines[i..-1].join(" ")
      parts = text_without_comments.split()
      if parts.length < 6
        return false
      end

      @required = parts[0]
      @matType = parts[1]
      @name = parts[2]
      if @matType == 'light' or @matType == 'glow'
        @defType = 'light'
      elsif Keywords_Pattern.has_key?(@matType)
        @defType = 'pattern'
      elsif @matType == 'alias'
        return false
      elsif Keywords_Material.has_key?(@matType) == false
        puts "Wrong material type #{@matType}\n"
        return false
      end
      ## now read details
      # if @matType == 'alias'
        # @required = parts[3]
        # @rest = parts[4..parts.length].join(' ')
        # @text = "void alias #{@name} #{@required}"
        # @defType = 'alias'
        # valid = true
      # else

      idx1 = 3
      step1 = Integer(parts[idx1])
      idx2 = 4 + step1
      if idx2>=parts.length
        return false
      end

      step2 = Integer(parts[idx2])
      idx3 = 5 + step1 + step2
      if idx3>=parts.length
        return false
      end

      nargs = Integer(parts[idx3])
      n = idx3 + nargs
      if n !=(parts.length-1)
        return false
      end

      line1 = parts[idx1...idx2].join(' ')
      line2 = parts[idx2...idx3].join(' ')
      line3 = parts[idx3..n].join(' ')

      @str_param = parts[idx1...idx2]
      @float_param = parts[idx3..n]
      #check number of str parameters
      if @str_param[0].to_i != (@str_param.size-1)
        puts "Wrong number of str parameters #{@str_param}\n"
        return valid
      end
      #check number of float parameters
      if @float_param[0].to_i != (@float_param.size-1)
        puts "Wrong number of float parameters #{@float_param}\n"
        return valid
      end
      @text = ["#{@required} #{@matType} #{@name}", line1, line2, line3].join("\n")
      #printf "\n#{@text}\n"
      if parts.length > n+1
        @rest = parts[n+1..parts.length].join(' ')
      end
      valid = true
      # end
      @text.strip!
      if @rest.strip == ''
        @rest = nil
      end
      return valid
    end

    # Returns material definition in Radiance format
    #   * singleline (boolean) - Flag whether text should be returned as single line or multiple lines
    def getText(singleline=false)
      ## return formated text with comments or on single line
      if singleline
        return @text.split().join(' ')
      elsif @comment != ''
        #return "## %s\n%s\n%s\n" % [@name, @comment, @text]
        return "%s\n%s\n" % [@comment, @text]
      else
        return "## %s\n%s" % [@name,@text]
      end
    end

    def setGroup(group)
      @_group = group
    end

    # Returns if material definition is valid
    def valid?
      return @valid
    end

    # Returns material comment
    def getComment()
      return @comment
    end

    # Returns list of material's float parameters
    def getFloatParam()
      return @float_param
    end

    # Returns list of material's string parameters
    def getStrParam()
      return @str_param
    end

    # Returns material reflection and tranmittance values depending on material type
    # It calls appropriate functions depending on material type - matal, plastic or glass
    # If none of these types, it returns [0,0]
    # returned values are in format +[ref,trans]+ where both values are in range [0,1]
    def getReflTrans()
      case @matType
         when "metal"   then return getMetPlasReflTrans()
         when "plastic" then return getMetPlasReflTrans()
         when "glass"   then return getGlassReflTrans()
         when "trans"   then return getTransReflTrans()
         else return [0,0]
      end
    end

    # Returns 'metal' or 'plastic' material refectance and transmittance=0
    def getMetPlasReflTrans()
      if @float_param[0].to_i != 5 then
        puts "Wrong number of float parameters for material #{identifier}\n"
        return [0,0]
      end
      reflectance = 0.265*@float_param[1].to_f + 0.670*@float_param[2].to_f + 0.065*@float_param[3].to_f
      return [reflectance,0]
    end

    # Returns 'glass' material refectance and transmittance
    # Transmittance is calculated from transmissivity with formulas from
    # Radiance function file 'trans.cal'
    def getGlassReflTrans()
      if (@float_param[0].to_i != 4 and @float_param[0].to_i != 3) then
        puts "Wrong number of float parameters for material #{identifier}\n"
        return [0,0]
      end
      tn = 0.265*@float_param[1].to_f + 0.670*@float_param[2].to_f + 0.065*@float_param[3].to_f #normal transmissivity
      if @float_param[0].to_i == 4 then
        n = @float_param[4].to_f
      else
        n = 1.52
      end
      rn = ((1-n)/(1+n))**2
      transmittance = (tn*(1-rn)*(1-rn)).to_f/(1-(tn*rn)**2)
      reflectance = rn + rn*((1-rn)*tn)**2/(1-(tn*rn)**2)
      printf "#{@name} tn=#{tn}, rn=#{rn}, Tn=#{transmittance}, Rn=#{reflectance}\n"
      return [reflectance, transmittance]
    end

    #Based on formulae in RWR book page 325
    def getTransReflTrans()
      red   = @float_param[1].to_f() *(1 - @float_param[4].to_f()) * (1 - @float_param[6].to_f())
      green = @float_param[2].to_f() *(1 - @float_param[4].to_f()) * (1 - @float_param[6].to_f())
      blue  = @float_param[3].to_f() *(1 - @float_param[4].to_f()) * (1 - @float_param[6].to_f())
      reflectance = 0.265 * red + 0.670 * green + 0.065 * blue
      transmittance = (reflectance * @float_param[6].to_f())/ (1- @float_param[6].to_f())
      return [reflectance, transmittance]
    end


    # Check if Radiance material is glazing - +glass+ or +BRTDfunc" with appropriate parameters
    def glazing?
      if @matType == 'glass'
        glazing = true
      elsif @matType =='BRTDfunc'
        trans_str = @str_param[4..6].join("")
        trans_float = @float_param[7..9].join("")
        if trans_str != "000" or trans_float != "000"
          print "#{trans_str} #{trans_float}\n"
          glazing = true
        else
          glazing = false
        end
      else
        glazing = false
      end
      return glazing
    end

    #Check if Radiance material is grey
    def grey?
      if ["plastic", "metal", "glass", "trans"].index(@matType) != nil
        if @float_param[1]==@float_param[2] and @float_param[2]==@float_param[3]
          return true
        else
          return false
        end
      else
        return false
      end
    end

    def translucent?
      if @matType == 'trans'
        if @float_param[7].to_f < 1.0
          return true
        end
      end
      return false
    end
  end

  # Radiance materials library defined in multiple material files
  class MaterialLibrary
    # Initialize library based on file +path+
    def initialize(path, name="")
      @materials = {}
      @name = name
      @files = []
      if path != ""
        addPath(path)
      end
      RadUtils.writeLog("=> %s" % getStats())
    end

    # returns string with number of materials and files in the library
    def inspect
      return "#<MaterialLibrary materials=%d files=%d" [@materials.length,@files.length]
    end

    # Add new file +path+ to materials' library
    #  1. If file is already in libarary - skip it
    #  2. If it is file #updateFromFile
    #  3. If it is directory - search for *.rad and 8.mat files recursively and add them to library
    #  4. else - print error message and return false
    def addPath(path)
      # skip file if it is already in libarary
      if @files.index(path) != nil
        return false
      end
      if FileTest.file?(path)
        return updateFromFile(path)
      elsif FileTest.directory?(path)
        RadUtils.writeLog(" searching in '#{path}'", 2)
        # paths = [] # unused
        Dir.foreach(path) { |f|
          filePath = File.join(path, f)
          if f.slice(0,1) == '.'
            next
          elsif FileTest.directory?(filePath) == true
            return addPath(filePath)
          elsif f.downcase.slice(-4,4) == '.rad'
            return updateFromFile(filePath)
          elsif f.downcase.slice(-4,4) == '.mat'
            return updateFromFile(filePath)
          end
        }
      else
        RadUtils.writeLog("Warning: Material library not file or directory: '#{path}'\n")
        puts "Warning: Material library not file or directory: '#{path}'\n"
        return false
      end
      return false #comes here only if directory 'path' is empty
    end

    # Update material definition
    #
    # If material is in the list update its value
    # If it isn't in the list add new material and set its value
    #
    #   * +name+ - name of the material
    #   * +material+ - #Material object
    def updateMaterial(name, material)
      if @materials[name] == nil
        #print "add new '#{name}' to database\n"
        @materials[name] = material
      else
        #puts "update existing material '#{name}'\n"
        @materials[name] = material
      end
    end

    ## Returns materials library statistics
    def getStats
      counts = Hash.new(0)
      @materials.each_value { |m|
        counts[m.getType()] += 1
        if not isDefined?(m)
          counts['undefined'] += 1
        end
      }
      text = "materials total: %d\n" % @materials.length
      counts.each_pair { |k,v|
        text += "%15s: %d\n" % [k,v]
      }
      return text
    end

    def getLibraryName()
      return @name
    end

    # Returns material object based on its name
    #
    #   * +mname+ (string) - material name
    def get(mname)
      radname = mname.gsub(/\s+/, '_')#.gsub(/\W/, '')
      return @materials[radname]
    end

    # Returns material by its name
    #
    #   * +mname+ (string) - material name
    def getByName(mname)
      return get(mname)
    end

    # Returns list of all material objects in library
    def getMaterials
      return @materials.values
    end

    #Return list of all material names in library
    def getMaterialsNames
      return @materials.keys.sort()
    end

    # For input material returns definition containing all required materials and final material definition
    # to be completely defined
    #
    #   * +mname+ (string) - material name
    def getMaterialWithDependencies(mname)
      radMat = get(mname)
      if not radMat
        return false
      end
      mdef = ""
      while radMat
        mdef = "%s\n%s" % [radMat.getText(), mdef]
        radMat = get(radMat.required)
      end
      return mdef.strip()
    end

    # Checks recursively if modifiers required for material are defined
    #
    #   * +m+ (string) - material object
    def isDefined?(m)
      req = m.required
      if req == 'void'
        return true
      elsif @materials.has_key?(req)
        return isDefined?(@materials[req])
      else
        return false
      end
    end

    #Return list of required materials names for current material
    #
    #   * +m+ (string) - material object
    def getRequiredList(m)
      req = m.required
      list = []
      if req == 'void'
        return []
      else
        while req != 'void'
          list.push(req)
          req = @materials[req].required
        end
        return list
      end
    end

    #Update hash 'materials' with keys and values from 'dict' Hash
    def update(dict)
      if dict.class == Hash
        dict.each_pair { |k,m|
          if m.getGroup() == 'alias' && @materials.has_key?(m.required)
            req = @materials[m.required]
            m.setGroup(req.getGroup())
          end
          @materials[k] = m
        }
      else
        RadUtils.writeLog("Error: can't update from object type '#{dict.class}'", -2)
      end
    end

    # Update list of libary files with new 'filepath' if it contains at least one Radiance material definition
    def updateFromFile(filepath)
      s = RadianceScene.new(filepath)
      sMats = s.materials
      if sMats.length > 0
        #RadUtils.writeLog(" > %3d materials in file '%s'" % [sMats.length, filepath], 1)
        #TODO search for preview images
        update(sMats)
        @files.push(filepath)
        return true
      else
        RadUtils.writeLog("no materials found in '#{filepath}'", 2)
        return false
      end
    end

    #Remove material from library based on its name
    #
    #return true/false
    def removeMaterial(mname)
      radname = mname.gsub(/\s+/, '_')#.gsub(/\W/, '')
      if @materials.key?(radname)
        @materials.delete(radname)
        return true
      end
      return false
    end


    # Returns material object based on its name
    #
    #   * +mname+ (string) - material name
    def get(mname)
      radname = mname.gsub(/\s+/, '_')#.gsub(/\W/, '')
      return @materials[radname]
    end


    # Gets reflection and transmitance values for the material from library
    #
    #   * +mname+ (string) - material name
    def getReflTrans(mname)
      material = get(mname)
      if material
        return material.getReflTrans()
      else
        return [0,0]
      end
    end

    # Gets material textual definition
    #
    #   * +mname+ (string) - material name
    def getDefinition(mname)
      material = get(mname)
      if material
        return material.getText()
      else
        return ""
      end
    end

    # Gets material comment if defined
    #
    #   * +mname+ (string) - material name
    def getComment(mname)
      material = get(mname)
      if material
        return material.getComment()
      else
        return ""
      end
    end

    # Gets material float parameters
    #
    #   * +mname+ (string) - material name
    def getFloatParam(mname)
      material = get(mname)
      if material
        return material.getFloatParam()
      else
        return nil
      end
    end

    # Gets material string parameters
    #
    #   * +mname+ (string) - material name
    def getStrParam(mname)
      material = get(mname)
      if material
        return material.getStrParam()
      else
        return nil
      end
    end

    # Gets material type
    #
    #   * +mname+ (string) - material name
    def getType(mname)
      material = get(mname)
      if material
        return material.getType()
      else
        return nil
      end
    end

    # Returns flag whether material is glazing or not
    #
    #   * +mname+ (string) - material name
    def glazing?(mname)
      material = get(mname)
      if material
        return material.glazing?()
      else
        return false
      end
    end

    # Returns flag whether material is grey or not
    #
    #   * +mname+ (string) - material name
    def grey?(mname)
      material = get(mname)
      if material
        return material.grey?()
      else
        return false
      end
    end

    # Returns flag whether material is translucent or not
    #
    #   * +mname+ (string) - material name
    def translucent?(mname)
      material = get(mname)
      if material
        return material.translucent?()
      else
        return false
      end
    end
  end

  class RadianceScene

    def initialize(filename=nil)
      @_name = 'undefined'
      @_definitions = []
      @materials = []
      if filename and readFile(filename)
        @_name = filename
      end
    end

    def inspect
      nMat = @materials.length
      nGeo = @_definitions.length - nMat
      return "#<RadianceScene '%s' elements=%d, materials=%d>" % [name,nGeo,nMat]
    end

    def getText
      lines = @_definitions.collect { |e| e.join("\n") }
      text = "##\n## %s\n##\n\n%s" % [@filename, lines.join("\n")]
      return text
    end

    def materials
      d = {}
      @materials.each { |m| d[m.name] = m }
      return d
    end

    def name
      if @_name == 'undefined'
        return 'undef_%s' % self.object_id
      else
        return @_name
      end
    end

    def print
      print getText()
    end

    def readFile(filename)
      begin
        lines = File.new(filename, 'r').readlines()
        text = purgeLines(lines)
        parseText(text)
      rescue => e
        msg = "%s\n  %s" % [$!.message,e.backtrace.join("\n  ")]
        printf "\n#{msg}\n"
        return false
      end
    end

    def _getKeywords(materials_only=false)
      keywords = {'alias' => true}
      keywords.update( Keywords_Material )
      keywords.update( Keywords_Pattern )
      if materials_only
        return keywords
      end
      keywords.update( Keywords_Geometry )
      keywords.update( Keywords_Pattern )
      return keywords
    end

    def parseText(text)
      if text.class == Array
        text = text.join(" ")
      end
      words = text.split()
      if words == []
        return
      end

      keywords = _getKeywords()
      elements = []
      _current = []
      _oldword = words[0]
      words.each { |word|
        if keywords.has_key?(word)
          if _current.length > 3
            _current.pop()
            elements.push(_current)
          end
          _current = [_oldword, word]
        else
          _current.push(word)
        end
        _oldword = word
      }
      elements.push(_current)
      matTypes = _getKeywords(true)
      elements.each { |line|
        if line.length > 2 and matTypes.has_key?(line[1])
          m = Material.new(line.join(" "))
          if m.valid?
            @materials.push(m)
          end
        end
        @_definitions.push(line)
      }
    end

    def parseText2(lines)
      keywords = _getKeywords()
      comments = []
      definition = []
      previous_comment = false
      lines.each{|l|
      if l[0] =='#'
        comments.push(l)
        previous_comment = true
      else
        definition.push(l)
        previous+comment = false
      end
    }


    end

    def purgeLines(lines)
      #lines = find_comments(lines)
      lines.collect! { |l| l.split('#')[0] }
      lines.compact!
      lines.collect! { |l| l.split().join(' ') }
      lines.collect! { |l| l if l != ''}
      lines.compact!
      return lines
    end

  end

end
end
