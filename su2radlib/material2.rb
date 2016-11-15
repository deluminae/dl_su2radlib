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

    GEOMETRY = {
      'bubble' => true,
      'cone' => true,
      'cup' => true,
      'cylinder' => true,
      'instance' => true,
      'polygon' => true,
      'ring' => true,
      'sphere' => true,
      'tube' => true
    }.freeze
    MATERIAL = {
      'antimatter' => true,
      'dielectric' => true,
      'interface' => true,
      'glass' => true,
      'glow' => true,
      'light' => true,
      'metal' => true,
      'metal2' => true,
      'mirror' => true,
      'mist' => true,
      'prism1' => true,
      'prism2' => true,
      'plastic' => true,
      'plastic2' => true,
      'trans' => true,
      'trans2' => true
    }.freeze
    PATTERN = {
      'BRTDfunc' => true,
      'brightfunc' => true,
      'brightdata' => true,
      'brighttext' => true,
      'colorfunc' => true,
      'colordata' => true,
      'colorpict' => true,
      'colortext' => true,
      'metfunc' => true,
      'metdata' => true,
      'plasfunc' => true,
      'plasdata' => true,
      'transfunc' => true,
      'transdata' => true,
      'mixfunc' => true,
      'mixdata' => true,
      'mixpict' => true,
      'mixtext' => true,
      'texfunc' => true,
      'texdata' => true
    }.freeze
    OTHER = {
      'void' => true,
      'alias' => true
    }.freeze
    SOURCE = {
      'illum' => true,
      'source' => true,
      'spotlight' => true
    }.freeze

    # Radiance material and its parameters
    #   * name - matrial name
    #   * comment - material drecriptio
    #   * modifier - Radiance modifier
    #   * type - Material type
    #   * text - text for Radiance definition
    #   * str_param - string parameters
    #   * float_param - float parameters
    #   * valid - Flag wether material definition is valid
    #   * required - Modifier required to be able to use this
    #   material (pattern/texture name or void)
    class Material2
      attr_reader :identifier, :definition, :comment, :modifier, :type
      attr_reader :valid, :required
      attr_reader :float_param, :str_param
      attr_reader :translucent, :grey, :glazing, :reflectance, :transmittance
      attr_reader :aliases

      def initialize(text)
        @identifier = ''
        @modifier = 'material'
        @type = nil
        @required = 'void'
        @definition = ''
        @comment = ''
        @_group = ''
        @valid = nil
        @str_param = nil
        @float_param = nil
        @int_param = nil
        @translucent = nil
        @grey = nil
        @glazing = nil
        @reflectance = nil
        @transmittance = nil
        #materials can have multiple alias material names
        @aliases = []
        parse_text text
      end

      def name
        return @identifier
      end

      # returns material type or group if material is glow or light material
      def group
        if @_group != ''
          return @_group
        elsif @type == 'light' || @type == 'glow'
          return 'light'
        elsif @type =~ /2\z/
          return $`
        else
          return @type
        end
      end

      # Parses Radiance definition of the material, and extracts parameters
      # Sets +valid+ variable value depending on parsing results
      # If parsing unsucessful - rested all instance varialbes
      def parse_text(text)
        @valid = _parse_text(text)
      #rescue => e
      #  printf "\nError in text: '#{text}'\n"
      #  msg = "%s\n%s" % [$!.message, e.backtrace.join("\n")]
      #  printf "\n#{msg}\n"
      #  @valid = false
      #  @identifier = ''
      #  @definition = ''
      #  @type = nil
      end

      # Do actual parsing of the +text+ and sets pappropriate instance variables
      def _parse_text(text)
        # force_identifier => will change the definition using new name
        comment = []
        content = []
        text.split("\n").each { |line|
          if line.index('#') == 0
            comment.push line
          else
            content.push line
          end
        }

        @comment = comment.join("\n").strip

        parts = content.join(' ').split
        return false if parts.length < 6

        @required = parts[0]
        @type = parts[1]
        @identifier = parts[2]
        if @type == 'light' || @type == 'glow'
          @modifier = 'light'
        elsif PATTERN.key?(@type)
          @modifier = 'pattern'
        elsif @type == 'alias'
          return false
        elsif !MATERIAL.key?(@type)
          #puts "Wrong material type #{@type}\n"
          return false
        end
        ## now read details
        # if @type == 'alias'
        # @required = parts[3]
        # @rest = parts[4..parts.length].join(' ')
        # @definition = "void alias #{@identifier} #{@required}"
        # @modifier = 'alias'
        # valid = true
        # else

        idx1 = 3
        nb_str = parts[idx1].to_i
        nb_float_position = 5 + nb_str
        zero_position = 4 + nb_str
        return false if zero_position >= parts.length

        step2 = parts[zero_position].to_i  # always zero
        nb_float_position = 5 + nb_str + step2
        return false if nb_float_position >= parts.length

        nb_float = parts[nb_float_position].to_i
        end_of_floats = nb_float_position + nb_float
        return false if end_of_floats != parts.length - 1

        @str_param = parts[idx1...zero_position]
        @int_param = parts[zero_position...nb_float_position]
        @float_param = parts[nb_float_position..end_of_floats]
        #check number of str parameters
        if @str_param[0].to_i != @str_param.size - 1
          #puts "Wrong number of str parameters #{@str_param}\n"
          return false
        end
        #check number of float parameters
        if @float_param[0].to_i != @float_param.size - 1
          #puts "Wrong number of float parameters #{@float_param}\n"
          return false
        end

        # definition is now valid
        return _compute_definition_and_values
      end

      def _compute_definition_and_values
        _make_definition
        _set_reflectance_transmittance
        if (@transmittance.to_s == 'NaN' || @reflectance.to_s == 'NaN' ||
            @transmittance < 0 ||  @reflectance < 0)
          return false
        end
        _set_glazing
        _set_grey
        _set_translucent
        return true
      end

      def _make_definition
        @definition = [
                       "#{@required} #{@type} #{@identifier}",
                       @str_param.join(' '),
                       @int_param.join(' '),
                       @float_param.join(' ')
        ].join("\n").strip + "\n"
      end

      def force_color(r, g, b)
        if ['plastic', 'metal', 'glass', 'trans'].index(@type) == nil
          return false
        end
        # assuming r, g, b are in 0..1 range
        @float_param[1] = r.to_s
        @float_param[2] = g.to_s
        @float_param[3] = b.to_s
        _compute_definition_and_values
        return true
      end

      def definition_single_line
        return @definition.split.join(' ').strip
      end

      def set_group(group)
        @_group = group
      end

      # Returns if material definition is valid
      def valid?
        return @valid
      end

      def set_name(name)
        return set_identifier(name)
      end

      def set_identifier(name)
        @identifier = name.gsub(/\n/, '').gsub(/ /, '_').strip
        _make_definition
      end

      def set_comment(comment)
        @comment = comment.gsub(/^# ?/, '').gsub(/^/,'# ').strip
      end

      def comment_unarmored
        return @comment.gsub(/^# ?/, '').strip
      end

      def comment_default
        return "## #{@identifier}"
      end

      def commented_definition
        return @comment + "\n" + @definition
      end

      def add_alias alias_name
        @aliases.push alias_name
        @aliases.uniq!
      end

      def set_aliases alias_list
        @aliases = alias_list
        @aliases.uniq!
      end

      def aliases_text
        text = ''
        @aliases.each { |a|
          text += "void alias #{a.gsub(/\s+/, '_')} #{identifier}\n"
        }
        return text
      end

      # It calls appropriate functions depending on material type - matal, plastic or glass
      # If none of these types, it returns [0,0]
      # returned values are in format +[ref,trans]+ where both values are in range [0,1]
      def _set_reflectance_transmittance
        case @type
        when 'metal'
          _setMetPlasReflTrans
        when 'plastic'
          _setMetPlasReflTrans
        when 'glass'
          _setGlassReflTrans
        when 'trans'
          _setTransReflTrans
        else
          @reflectance = 0
          @transmittance = 0
        end
      end

      # Returns 'metal' or 'plastic' material refectance and transmittance=0
      def _setMetPlasReflTrans
        if @float_param[0].to_i != 5
          #puts "Wrong number of float parameters for material #{identifier}\n"
          @reflectance = 0
          @transmittance = 0
          return
        end
        @reflectance = (0.265 * @float_param[1].to_f +
                        0.670 * @float_param[2].to_f +
                        0.065 * @float_param[3].to_f)
        @transmittance = 0
      end

      # Returns 'glass' material refectance and transmittance
      # Transmittance is calculated from transmissivity with formulas from
      # Radiance function file 'trans.cal'
      def _setGlassReflTrans
        if @float_param[0].to_i != 4 && @float_param[0].to_i != 3
          #puts "Wrong number of float parameters for material #{identifier}\n"
          @reflectance = 0
          @transmittance = 0
          return
        end
        tn = (0.265 * @float_param[1].to_f +
              0.670 * @float_param[2].to_f +
              0.065 * @float_param[3].to_f) #normal transmissivity

        if @float_param[0].to_i == 4
          n = @float_param[4].to_f
        else
          n = 1.52
        end

        rn = ((1 - n) / (1 + n))**2
        @transmittance = (tn * (1 - rn) * (1 - rn)).to_f / (1 - (tn * rn)**2)
        @reflectance = rn + rn * ((1 - rn) * tn)**2 / (1 - (tn * rn)**2)
        #printf "#{@identifier} tn=#{tn}, rn=#{rn}, Tn=#{@transmittance}, Rn=#{@reflectance}\n"
      end

      #Based on formulae in RWR book page 325
      def _setTransReflTrans
        red   = (@float_param[1].to_f *
                  (1 - @float_param[4].to_f) * (1 - @float_param[6].to_f))
        green = (@float_param[2].to_f *
                  (1 - @float_param[4].to_f) * (1 - @float_param[6].to_f))
        blue  = (@float_param[3].to_f *
                  (1 - @float_param[4].to_f) * (1 - @float_param[6].to_f))
        @reflectance = 0.265 * red + 0.670 * green + 0.065 * blue
        @transmittance = ((reflectance * @float_param[6].to_f) /
                          (1 - @float_param[6].to_f))
      end

      # Check if Radiance material is glazing - +glass+ or +BRTDfunc" with appropriate parameters
      def glazing?
        return @glazing
      end

      def _set_glazing
        if @type == 'glass'
          @glazing = true
        elsif @type == 'BRTDfunc'
          trans_str = @str_param[4..6].join('')
          trans_float = @float_param[7..9].join('')
          if trans_str != "000" || trans_float != '000'
            #print "#{trans_str} #{trans_float}\n"
            @glazing = true
          else
            @glazing = false
          end
        else
          @glazing = false
        end
      end

      #Check if Radiance material is grey
      def grey?
        return @grey
      end

      def _set_grey
        @grey = (['plastic', 'metal', 'glass', 'trans'].index(@type) != nil &&
                 @float_param[1] == @float_param[2] &&
                 @float_param[2] == @float_param[3])
      end

      def translucent?
        return @translucent
      end

      def _set_translucent
        @translucent = (@type == 'trans' && @float_param[7].to_f < 1.0)
      end

    end

  end
end
