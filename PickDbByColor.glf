#
# Copyright 2012 (c) Pointwise, Inc.
# All rights reserved.
#
# This sample Pointwise script is not supported by Pointwise, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#

package require PWI_Glyph 2
pw::Script loadTk

###
# Globals
###

set allLineColors [list]
set allSurfColors [list]
set DefaultDbColor "#df7ece"


###
# return the unique set of all line and surface colors in the database
###

proc getCurrentColors { choice } {
  global allLineColors allSurfColors

  foreach db [pw::Database getAll] {
    set dbColor [$db getColor]

    switch -nocase $choice {
      linecolor {
        if { [$db isCurve] && [lsearch $allLineColors $dbColor] == -1 } {
          lappend allLineColors [$db getColor]
        }
      }
      surfcolor {
        if { [$db isSurface] && [lsearch $allSurfColors $dbColor] == -1 } {
          lappend allSurfColors [$db getColor]
        }
      }
    }
  }

  switch -nocase $choice {
    linecolor {
      return $allLineColors
    }
    surfcolor {
      return $allSurfColors
    }
  }

  return -code error "invalid argument \"$choice\""
}


###
# return the set of database entities that match the given line or surface color
###

proc getEntitiesByColor { lineColor surfColor } {
  global IncludeHidden

  set disabledVisible [pw::Display getShowDisabledEntities]

  if { $surfColor == "ALL" && $lineColor == "ALL" } {
    return [pw::Database getAll]
  }

  set result [list]
  foreach db [pw::Database getAll] {
    if { ! $IncludeHidden && ! [pw::Display isLayerVisible [$db getLayer]] } {
      continue
    }
    if { ! $IncludeHidden && ! $disabledVisible && ! [$db getEnabled] } {
      continue
    }
    if { [$db isSurface] && $surfColor != "NONE" && \
         ($surfColor == "ALL" || [$db getColor] == $surfColor) } {
      lappend result $db
    } elseif { [$db isCurve] && $lineColor != "NONE" && \
         ($lineColor == "ALL" || [$db getColor] == $lineColor) } {
      lappend result $db
    }
  }

  return $result
}


###
# process color selection change
###

proc doColorChanged { type newColor } {
  global mindex allLineColors allSurfColors DefaultBgColor DefaultDbColor t$type

  set mindex($type) $newColor

  if { $newColor < 2 } {
    set color $DefaultBgColor
    if { $newColor == 0 } {
      set t$type "NONE"
    } else {
      set t$type "ALL"
    }
  } else {
    switch $type {
      linecolor {
        set color \
          "#[string range [lindex $allLineColors [expr $newColor-2]] 4 10]"
      }
      surfcolor {
        set color \
          "#[string range [lindex $allSurfColors [expr $newColor-2]] 4 10]"
      }
    }
    set t$type "        "
  }

  if { $color == "#000000" } {
    set color $DefaultDbColor
  }

  .work.fcolor.$type configure -background $color
  .work.fcolor.$type configure -activebackground $color
  update
  doUpdateWidgets
}


###
# create the color option menu for a given db entity type
###

proc makeColorMenu { frame type } {
  global mindex DefaultDbColor

  set colors [getCurrentColors $type]
  set m [tk_optionMenu $frame.$type mindex($type) NONE ALL]

  $frame.$type configure -textvariable t$type

  $m entryconfigure 0 -command "doColorChanged $type 0"
  $m entryconfigure 1 -command "doColorChanged $type 1"

  set i 2
  foreach color $colors {
    if { $color != "0x00000000" } {
      set newColor "#[string range $color 4 10]"
    } else {
      set newColor $DefaultDbColor
    }
    $m add checkbutton -background $newColor -label "       " \
        -onvalue $i -offvalue 0 -variable mindex($type) \
        -command "doColorChanged $type $i"
    incr i 1
  }

  set mindex($type) 0

  return $m
}


###
# show the entities that would be actionable with the current criteria
###

proc doPreview { } {
  global IncludeHidden

  set sel [getEntities]

  if { [llength $sel] > 0 } {
    wm withdraw .

    set disabled [list]
    set layers [list]

    # temporarily enable hidden entities as needed
    if $IncludeHidden {
      set layer [pw::Display getCurrentLayer]
      foreach db $sel {
        if { ! [$db getEnabled] || \
             ! [pw::Display isLayerVisible [$db getLayer]] } {
          lappend disabled $db
          lappend layers [$db getLayer]
          $db setEnabled 1
          $db setLayer $layer
        }
      }
      pw::Display update
    }

    set mask [pw::Display createSelectionMask -requireDatabase {}]

    pw::Display selectEntities -description \
        "Current selection based on color criteria.\n\n \
         Hidden entities are only temporarily displayed.\n\n \
         (NOTE: this is preview only, changes made to this selection \
         do not affect the results of the query)" \
      -preselect $sel -selectionmask $mask unused

    foreach db $disabled layer $layers {
      $db setEnabled 0
      $db setLayer $layer
    }
    pw::Display update

    if [winfo exists .] {
      wm deiconify .
    }
  } else {
    tk_dialog .diag "Empty Selection" \
        "No database entities match the current criteria." "" 0 OK
  }
}


###
# return the entities that match the current criteria
###

proc getEntities { } {
  global mindex allLineColors allSurfColors

  switch $mindex(linecolor) {
    0 {
      set line NONE
    }
    1 {
      set line ALL
    }
    default {
      set line [lindex $allLineColors [expr {$mindex(linecolor) - 2}]]
    }
  }

  switch $mindex(surfcolor) {
    0 {
      set surf NONE
    }
    1 {
      set surf ALL
    }
    default {
      set surf [lindex $allSurfColors [expr {$mindex(surfcolor) - 2}]]
    }
  }

  return [getEntitiesByColor $line $surf]
}


###
# process the selected entities according to the GUI settings
###

proc doPerformActions { } {
  global action val

  set dbList [getEntities]
  set errors [list]

  if [llength $dbList] {
    if { $action(Layer) } {
      set tempCol [pw::Collection create]
      $tempCol set $dbList
      catch { $tempCol do setLayer $val(Layer) }
      $tempCol delete
    }

    if { $action(Group) } {
      if [catch { pw::Group getByName $val(Group) } group] {
        set group [pw::Group create]
        $group setName $val(Group)
        $group setEntityType pw::DatabaseEntity
      } else {
        if { [string trimleft [$group getEntityType] ":"] != \
              "pw::DatabaseEntity" } {
          lappend errors \
              "Existing group '$val(Group)' not a database entity group"
          unset group
        }
      }
      if [info exists group] {
        eval [concat $group addEntity $dbList]
      }
    }

    if { $action(Enable) } {
      set tempCol [pw::Collection create]
      $tempCol set $dbList
      if [catch {
        $tempCol do setEnabled [string equal $val(Enable) "Enable"]
      } msg] {
        lappend errors "$msg"
      }
      $tempCol delete
    }
  } else {
    lappend errors "No database entities match the current criteria."
  }

  pw::Display update

  if [llength $errors] {
    set msg [join $errors "\n"]
    tk_messageBox -icon error \
      -message "Errors occured while processing:\n\n$msg" \
      -parent . -title "Error" -type ok
  }
}


###
# adjust widget sensitivity based on GUI control settings
###

proc doUpdateWidgets { } {
  global val action mindex

  set canApply [expr $action(Group) || $action(Enable) || $action(Layer)]

  if $action(Group) {
    .work.faction.grp.ent configure -state normal
    if [string length $val(Group)] {
      .work.faction.grp.ent configure -background #FFFFFF
    } else {
      .work.faction.grp.ent configure -background #FFCCCC
      set canApply 0
    }
  } else {
    .work.faction.grp.ent configure -state disabled
  }

  if $action(Layer) {
    .work.faction.layer.ent configure -state normal
    if { [string length $val(Layer)] && [string is integer $val(Layer)] && \
         $val(Layer) >= 0 && $val(Layer) < 1024 } {
      .work.faction.layer.ent configure -background #FFFFFF
    } else {
      .work.faction.layer.ent configure -background #FFCCCC
      set canApply 0
    }
  } else {
    .work.faction.layer.ent configure -state disabled
  }

  if { $mindex(linecolor) == 0 && $mindex(surfcolor) == 0 } {
    .work.fcolor.preview configure -state disabled
    set canApply 0
  } else {
    .work.fcolor.preview configure -state normal
  }

  if $canApply {
    .buttons.ok configure -state normal
    .buttons.apply configure -state normal
  } else {
    .buttons.ok configure -state disabled
    .buttons.apply configure -state disabled
  }

  return 1
}


###
# create the GUI window
###

proc makeWindow { } {
  global val action DefaultBgColor IncludeHidden

  set IncludeHidden 0
  set DefaultBgColor [. cget -background]

  label .title -text "Pick Database Entity by Color"
  set font [.title cget -font]
  .title configure -font \
      [font create -family [font actual $font -family] -weight bold]

  frame .hr1 -height 2 -relief sunken -bd 1
  frame .work

  labelframe .work.fcolor -text "Color Query" -bd 2 -relief sunken
  label .work.fcolor.line -text "Line Color: " -bd 0
  makeColorMenu .work.fcolor linecolor
  label .work.fcolor.surf -text "Surface Color: " -bd 0
  makeColorMenu .work.fcolor surfcolor
  checkbutton .work.fcolor.cbhidden -variable IncludeHidden \
      -text "Include hidden entities"
  frame .work.fcolor.hr -height 2 -relief sunken -bd 2
  button .work.fcolor.preview -text "Preview Selection" -command { doPreview }

  labelframe .work.faction -text "Action" -bd 2 -relief sunken
  frame .work.faction.layer
  checkbutton .work.faction.layer.cb -variable action(Layer) \
      -text "Move to Layer:" -command { doUpdateWidgets }
  entry .work.faction.layer.ent -textvariable val(Layer) -width 15 \
      -justify right -validate all -validatecommand { doUpdateWidgets }
  frame .work.faction.viz
  checkbutton .work.faction.viz.cb -variable action(Enable) \
      -text "Enable/Disable: " -command { doUpdateWidgets }
  tk_optionMenu .work.faction.viz.menu val(Enable) "Enable" "Disable"
  frame .work.faction.grp
  checkbutton .work.faction.grp.cb -variable action(Group) \
      -text "Add to Group: " -command { doUpdateWidgets }
  entry .work.faction.grp.ent -textvariable val(Group) -width 15 \
      -validate all -validatecommand { doUpdateWidgets }

  frame .hr2 -height 2 -relief sunken -bd 1
  frame .buttons
  button .buttons.cancel -text "Close" -command { exit }
  button .buttons.apply -text "Apply" -command { doPerformActions }
  button .buttons.ok -text "OK" -command {
    .buttons.apply invoke
    exit
  }
  label .buttons.logo -image [pwLogo]
  .buttons.logo configure -bd 0 -relief flat

  pack .title -side top
  pack .hr1 -side top -padx 2 -fill x -pady 2
  pack .work -side top -expand 1 -fill both

  pack .work.fcolor -side left -padx 3 -pady 3 -fill y
  grid .work.fcolor.line -row 0 -column 0 -sticky e -padx 2
  grid .work.fcolor.linecolor -row 0 -column 1 -sticky ew -padx 2
  grid .work.fcolor.surf -row 1 -column 0 -sticky e -padx 2
  grid .work.fcolor.surfcolor -row 1 -column 1 -sticky ew -padx 2
  grid .work.fcolor.cbhidden -row 2 -column 0 -columnspan 2 -sticky ew -padx 2
  grid .work.fcolor.hr -row 3 -column 0 -columnspan 2 -sticky ew -padx 9 -pady 5
  grid .work.fcolor.preview -row 4 -column 0 -columnspan 2

  pack .work.faction -side right -padx 3 -pady 3 -fill both
  grid .work.faction.layer -row 0 -column 0 -sticky ew
  pack .work.faction.layer.cb -side left
  pack .work.faction.layer.ent -side right -fill x
  grid .work.faction.viz -row 1 -column 0 -sticky ew
  pack .work.faction.viz.cb -side left
  pack .work.faction.viz.menu -side right -fill x
  grid .work.faction.grp -row 2 -column 0 -sticky ew
  pack .work.faction.grp.cb -side left
  pack .work.faction.grp.ent -side right -fill x

  pack .buttons -side bottom -pady 2 -fill x
  pack .buttons.logo -side left
  pack .buttons.cancel -padx 2 -side right
  pack .buttons.apply -padx 4 -side right
  pack .buttons.ok -padx 2 -side right

  wm title . "Pick Database Entities By Color"

  bind . <Key-Return> { .buttons.ok invoke }
  bind . <KeyPress-Escape> { .buttons.cancel invoke }
}


###
# return the Pointwise logo image
###

proc pwLogo {} {
  set logoData "
R0lGODlheAAYAIcAAAAAAAICAgUFBQkJCQwMDBERERUVFRkZGRwcHCEhISYmJisrKy0tLTIyMjQ0
NDk5OT09PUFBQUVFRUpKSk1NTVFRUVRUVFpaWlxcXGBgYGVlZWlpaW1tbXFxcXR0dHp6en5+fgBi
qQNkqQVkqQdnrApmpgpnqgpprA5prBFrrRNtrhZvsBhwrxdxsBlxsSJ2syJ3tCR2siZ5tSh6tix8
ti5+uTF+ujCAuDODvjaDvDuGujiFvT6Fuj2HvTyIvkGKvkWJu0yUv2mQrEOKwEWNwkaPxEiNwUqR
xk6Sw06SxU6Uxk+RyVKTxlCUwFKVxVWUwlWWxlKXyFOVzFWWyFaYyFmYx16bwlmZyVicyF2ayFyb
zF2cyV2cz2GaxGSex2GdymGezGOgzGSgyGWgzmihzWmkz22iymyizGmj0Gqk0m2l0HWqz3asznqn
ynuszXKp0XKq1nWp0Xaq1Hes0Xat1Hmt1Xyt0Huw1Xux2IGBgYWFhYqKio6Ojo6Xn5CQkJWVlZiY
mJycnKCgoKCioqKioqSkpKampqmpqaurq62trbGxsbKysrW1tbi4uLq6ur29vYCu0YixzYOw14G0
1oaz14e114K124O03YWz2Ie12oW13Im10o621Ii22oi23Iy32oq52Y252Y+73ZS51Ze81JC625G7
3JG825K83Je72pW93Zq92Zi/35G+4aC90qG+15bA3ZnA3Z7A2pjA4Z/E4qLA2KDF3qTA2qTE3avF
36zG3rLM3aPF4qfJ5KzJ4LPL5LLM5LTO4rbN5bLR6LTR6LXQ6r3T5L3V6cLCwsTExMbGxsvLy8/P
z9HR0dXV1dbW1tjY2Nra2tzc3N7e3sDW5sHV6cTY6MnZ79De7dTg6dTh69Xi7dbj7tni793m7tXj
8Nbk9tjl9N3m9N/p9eHh4eTk5Obm5ujo6Orq6u3t7e7u7uDp8efs8uXs+Ozv8+3z9vDw8PLy8vL0
9/b29vb5+/f6+/j4+Pn6+/r6+vr6/Pn8/fr8/Pv9/vz8/P7+/gAAACH5BAMAAP8ALAAAAAB4ABgA
AAj/AP8JHEiwoMGDCBMqXMiwocOHECNKnEixosWLGDNqZCioo0dC0Q7Sy2btlitisrjpK4io4yF/
yjzKRIZPIDSZOAUVmubxGUF88Aj2K+TxnKKOhfoJdOSxXEF1OXHCi5fnTx5oBgFo3QogwAalAv1V
yyUqFCtVZ2DZceOOIAKtB/pp4Mo1waN/gOjSJXBugFYJBBflIYhsq4F5DLQSmCcwwVZlBZvppQtt
D6M8gUBknQxA879+kXixwtauXbhheFph6dSmnsC3AOLO5TygWV7OAAj8u6A1QEiBEg4PnA2gw7/E
uRn3M7C1WWTcWqHlScahkJ7NkwnE80dqFiVw/Pz5/xMn7MsZLzUsvXoNVy50C7c56y6s1YPNAAAC
CYxXoLdP5IsJtMBWjDwHHTSJ/AENIHsYJMCDD+K31SPymEFLKNeM880xxXxCxhxoUKFJDNv8A5ts
W0EowFYFBFLAizDGmMA//iAnXAdaLaCUIVtFIBCAjP2Do1YNBCnQMwgkqeSSCEjzzyJ/BFJTQfNU
WSU6/Wk1yChjlJKJLcfEgsoaY0ARigxjgKEFJPec6J5WzFQJDwS9xdPQH1sR4k8DWzXijwRbHfKj
YkFO45dWFoCVUTqMMgrNoQD08ckPsaixBRxPKFEDEbEMAYYTSGQRxzpuEueTQBlshc5A6pjj6pQD
wf9DgFYP+MPHVhKQs2Js9gya3EB7cMWBPwL1A8+xyCYLD7EKQSfEF1uMEcsXTiThQhmszBCGC7G0
QAUT1JS61an/pKrVqsBttYxBxDGjzqxd8abVBwMBOZA/xHUmUDQB9OvvvwGYsxBuCNRSxidOwFCH
J5dMgcYJUKjQCwlahDHEL+JqRa65AKD7D6BarVsQM1tpgK9eAjjpa4D3esBVgdFAB4DAzXImiDY5
vCFHESko4cMKSJwAxhgzFLFDHEUYkzEAG6s6EMgAiFzQA4rBIxldExBkr1AcJzBPzNDRnFCKBpTd
gCD/cKKKDFuYQoQVNhhBBSY9TBHCFVW4UMkuSzf/fe7T6h4kyFZ/+BMBXYpoTahB8yiwlSFgdzXA
5JQPIDZCW1FgkDVxgGKCFCywEUQaKNitRA5UXHGFHN30PRDHHkMtNUHzMAcAA/4gwhUCsB63uEF+
bMVB5BVMtFXWBfljBhhgbCFCEyI4EcIRL4ChRgh36LBJPq6j6nS6ISPkslY0wQbAYIr/ahCeWg2f
ufFaIV8QNpeMMAkVlSyRiRNb0DFCFlu4wSlWYaL2mOp13/tY4A7CL63cRQ9aEYBT0seyfsQjHedg
xAG24ofITaBRIGTW2OJ3EH7o4gtfCIETRBAFEYRgC06YAw3CkIqVdK9cCZRdQgCVAKWYwy/FK4i9
3TYQIboE4BmR6wrABBCUmgFAfgXZRxfs4ARPPCEOZJjCHVxABFAA4R3sic2bmIbAv4EvaglJBACu
IxAMAKARBrFXvrhiAX8kEWVNHOETE+IPbzyBCD8oQRZwwIVOyAAXrgkjijRWxo4BLnwIwUcCJvgP
ZShAUfVa3Bz/EpQ70oWJC2mAKDmwEHYAIxhikAQPeOCLdRTEAhGIQKL0IMoGTGMgIBClA9QxkA3U
0hkKgcy9HHEQDcRyAr0ChAWWucwNMIJZ5KilNGvpADtt5JrYzKY2t8nNbnrzm+B8SEAAADs="

  return [image create photo -format GIF -data $logoData]
}


###
# main
###

makeWindow
doUpdateWidgets
::tk::PlaceWindow . widget

#
# DISCLAIMER:
# TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, POINTWISE DISCLAIMS
# ALL WARRANTIES, EITHER EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED
# TO, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE, WITH REGARD TO THIS SCRIPT.  TO THE MAXIMUM EXTENT PERMITTED
# BY APPLICABLE LAW, IN NO EVENT SHALL POINTWISE BE LIABLE TO ANY PARTY
# FOR ANY SPECIAL, INCIDENTAL, INDIRECT, OR CONSEQUENTIAL DAMAGES
# WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF
# BUSINESS INFORMATION, OR ANY OTHER PECUNIARY LOSS) ARISING OUT OF THE
# USE OF OR INABILITY TO USE THIS SCRIPT EVEN IF POINTWISE HAS BEEN
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGES AND REGARDLESS OF THE
# FAULT OR NEGLIGENCE OF POINTWISE.
#
