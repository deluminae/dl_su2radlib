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

module Test

  currentDir = File.dirname(__FILE__).force_encoding('UTF-8')
  require(File.join(currentDir, "material2"))
  require(File.join(currentDir, "material_library_simple"))

  include DL::SU2rad

  path = File.join(currentDir, "K_and_E.rad")
  #path = File.join(currentDir, "materials.rad")
  #path = File.join(currentDir, "ral.rad")
  if File.exist? path
    ml = MaterialLibrarySimple.new(path)
    puts ml.length
    test_path = File.join(currentDir, "test.rad")
    ml.set_path(test_path)
    puts ml.dump_file
    ml2 = MaterialLibrarySimple.new(test_path)
    puts ml2.length
    id = ml.get_identifiers()[5]
    puts id
    mat = ml.get(id)
    puts '---'
    puts mat.definition
    puts '---'
    puts mat.comment
    puts '---'
    puts mat.commented_definition
    puts '---'
    list = ml.get_identifiers
    puts "#{list}"
    puts 'reordering'
    b = list[1..129] + [list[0]]
    ml.reorder_materials(b)
    puts "#{ml.get_identifiers}"
    puts
    puts ml.is_defined?(mat)
    puts "#{ml.get_required_list(mat)}"
    puts ml.remove_material('xxx')
    puts ml.length
    puts ml.remove_material(id)
    puts ml.length
    puts "get removed :"
    puts ml.get(id) || 'none'
    n = ml.get_identifiers()[7]
    mat = ml.get(n)
    puts n
    puts mat.reflectance
    puts ml.get_reflectance(n)
    puts
    puts mat.tranmittance
    puts ml.get_tranmittance(n)
    puts
    puts mat.definition
    puts ml.get_definition(n)
    puts
    puts mat.comment
    puts ml.get_comment(n)
    puts
    puts mat.commented_definition
    puts ml.get_commented_definition(n)
    puts
    puts mat.float_param
    puts ml.get_float_param(n)
    puts
    puts mat.str_param
    puts ml.get_str_param(n)
    puts
    puts mat.type
    puts ml.get_type(n)
    puts
    puts mat.grey
    puts mat.grey?
    puts ml.grey?(n)
    puts
    puts mat.glazing
    puts mat.glazing?
    puts ml.glazing?(n)
    puts
    puts mat.translucent
    puts mat.translucent?
    puts ml.translucent?(n)
    puts
    puts mat.definition_single_line
    puts mat.valid?
    puts mat.identifier
    puts mat.name
  end # test file
  puts "==================================="
  puts "complex content :"
  puts "==================================="

  content =<<EOF
# line 1
# line 2

# line 3


##
## some lines above 1e101

## (this one has a dependency)
1E105xxxgood plastic 1E101good
0
# inner comment of 1e101
0
5 0.737 0.646
# inner comment 2 of 1e101
! one line command
# inner comment 3 of 1e101
0.602 0.03 0.02

# some alias to drop
void alias xxx yyy

# some good alias
void alias alias101 1E101good
# some second alias
void alias alias102 1E101good


## 1E105good
void plastic 1E105good
0 0 5 0.224 0.196 0.173 0.03 0.02
#after comment is dropped

void alias a105 1E105good

!(some alone 3 lines  \
command line \
# with comment inside
)

## 1E119bad
void plasticooooo 1E119bad
0
0
! hello
5
0.118 0.121 0.136 0.03 0.02


## some good if bad ones before
void plastic 1E105xxxgood
! hello
0 0 5 0.224 0.196 0.173 0.03 0.02

EOF


puts 'loading content, nb of materials:'
ml = MaterialLibrarySimple.new
ml.load_content(content)
puts ml.length
puts '---- initial comment:'
puts ml.description
puts '---- first material commented def:'
m = ml.get(ml.get_identifiers()[0])
puts m.commented_definition
puts '--- show material 105 aliases before and after add a alias'
puts ml.get_aliases_text('1E105good')
puts '===>'
m = ml.get('1E105good')
m.add_alias('foo')
ml.update_material(m)
puts ml.get_aliases_text('1E105good')
puts '--- show material called by alias'
m =ml.get_alias('foo')
puts m.definition
puts '--- mat content :'
puts m.identifier
puts m.definition
puts m.reflectance
puts m.transmittance
puts m.glazing
puts m.grey
puts m.translucent
puts m.aliases
puts m.aliases_text
puts '---'
ml.get_required_list(m)
m.comment_unarmored + "\n"
puts '---- full content:'
puts ml.get_full_content
puts '----'
puts '---- full content without aliases:'
puts ml.get_full_content_without_aliases
puts '---'
mat = ml.get('1E101good')
puts ml.is_defined?(mat)
puts "req: #{ml.get_required_list(mat)}"
end
