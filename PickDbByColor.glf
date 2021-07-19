#############################################################################
#
# (C) 2021 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This sample script is not supported by Cadence Design Systems, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#############################################################################

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
  label .buttons.logo -image [cadenceLogo]
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
# return the Cadence Design Systems logo image
###

proc cadenceLogo {} {
  set logoData "
R0lGODlhgAAYAPQfAI6MjDEtLlFOT8jHx7e2tv39/RYSE/Pz8+Tj46qoqHl3d+vq62ZjY/n4+NT
T0+gXJ/BhbN3d3fzk5vrJzR4aG3Fubz88PVxZWp2cnIOBgiIeH769vtjX2MLBwSMfIP///yH5BA
EAAB8AIf8LeG1wIGRhdGF4bXD/P3hwYWNrZXQgYmVnaW49Iu+7vyIgaWQ9Ilc1TTBNcENlaGlIe
nJlU3pOVGN6a2M5ZCI/PiA8eDp4bXBtdGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1w
dGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYxIDY0LjE0MDk0OSwgMjAxMC8xMi8wNy0xMDo1Nzo
wMSAgICAgICAgIj48cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudy5vcmcvMTk5OS8wMi
8yMi1yZGYtc3ludGF4LW5zIyI+IDxyZGY6RGVzY3JpcHRpb24gcmY6YWJvdXQ9IiIg/3htbG5zO
nhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdFJlZj0iaHR0
cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUcGUvUmVzb3VyY2VSZWYjIiB4bWxuczp4bXA9Imh
0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtcE1NOk9yaWdpbmFsRG9jdW1lbnRJRD0idX
VpZDoxMEJEMkEwOThFODExMUREQTBBQzhBN0JCMEIxNUM4NyB4bXBNTTpEb2N1bWVudElEPSJ4b
XAuZGlkOkIxQjg3MzdFOEI4MTFFQjhEMv81ODVDQTZCRURDQzZBIiB4bXBNTTpJbnN0YW5jZUlE
PSJ4bXAuaWQ6QjFCODczNkZFOEI4MTFFQjhEMjU4NUNBNkJFRENDNkEiIHhtcDpDcmVhdG9yVG9
vbD0iQWRvYmUgSWxsdXN0cmF0b3IgQ0MgMjMuMSAoTWFjaW50b3NoKSI+IDx4bXBNTTpEZXJpZW
RGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6MGE1NjBhMzgtOTJiMi00MjdmLWE4ZmQtM
jQ0NjMzNmNjMWI0IiBzdFJlZjpkb2N1bWVudElEPSJ4bXAuZGlkOjBhNTYwYTM4LTkyYjItNDL/
N2YtYThkLTI0NDYzMzZjYzFiNCIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g
6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/PgH//v38+/r5+Pf29fTz8vHw7+7t7Ovp6Ofm5e
Tj4uHg397d3Nva2djX1tXU09LR0M/OzczLysnIx8bFxMPCwcC/vr28u7q5uLe2tbSzsrGwr66tr
KuqqainpqWko6KhoJ+enZybmpmYl5aVlJOSkZCPjo2Mi4qJiIeGhYSDgoGAf359fHt6eXh3dnV0
c3JxcG9ubWxramloZ2ZlZGNiYWBfXl1cW1pZWFdWVlVUU1JRUE9OTUxLSklIR0ZFRENCQUA/Pj0
8Ozo5ODc2NTQzMjEwLy4tLCsqKSgnJiUkIyIhIB8eHRwbGhkYFxYVFBMSERAPDg0MCwoJCAcGBQ
QDAgEAACwAAAAAgAAYAAAF/uAnjmQpTk+qqpLpvnAsz3RdFgOQHPa5/q1a4UAs9I7IZCmCISQwx
wlkSqUGaRsDxbBQer+zhKPSIYCVWQ33zG4PMINc+5j1rOf4ZCHRwSDyNXV3gIQ0BYcmBQ0NRjBD
CwuMhgcIPB0Gdl0xigcNMoegoT2KkpsNB40yDQkWGhoUES57Fga1FAyajhm1Bk2Ygy4RF1seCjw
vAwYBy8wBxjOzHq8OMA4CWwEAqS4LAVoUWwMul7wUah7HsheYrxQBHpkwWeAGagGeLg717eDE6S
4HaPUzYMYFBi211FzYRuJAAAp2AggwIM5ElgwJElyzowAGAUwQL7iCB4wEgnoU/hRgIJnhxUlpA
SxY8ADRQMsXDSxAdHetYIlkNDMAqJngxS47GESZ6DSiwDUNHvDd0KkhQJcIEOMlGkbhJlAK/0a8
NLDhUDdX914A+AWAkaJEOg0U/ZCgXgCGHxbAS4lXxketJcbO/aCgZi4SC34dK9CKoouxFT8cBNz
Q3K2+I/RVxXfAnIE/JTDUBC1k1S/SJATl+ltSxEcKAlJV2ALFBOTMp8f9ihVjLYUKTa8Z6GBCAF
rMN8Y8zPrZYL2oIy5RHrHr1qlOsw0AePwrsj47HFysrYpcBFcF1w8Mk2ti7wUaDRgg1EISNXVwF
lKpdsEAIj9zNAFnW3e4gecCV7Ft/qKTNP0A2Et7AUIj3ysARLDBaC7MRkF+I+x3wzA08SLiTYER
KMJ3BoR3wzUUvLdJAFBtIWIttZEQIwMzfEXNB2PZJ0J1HIrgIQkFILjBkUgSwFuJdnj3i4pEIlg
eY+Bc0AGSRxLg4zsblkcYODiK0KNzUEk1JAkaCkjDbSc+maE5d20i3HY0zDbdh1vQyWNuJkjXnJ
C/HDbCQeTVwOYHKEJJwmR/wlBYi16KMMBOHTnClZpjmpAYUh0GGoyJMxya6KcBlieIj7IsqB0ji
5iwyyu8ZboigKCd2RRVAUTQyBAugToqXDVhwKpUIxzgyoaacILMc5jQEtkIHLCjwQUMkxhnx5I/
seMBta3cKSk7BghQAQMeqMmkY20amA+zHtDiEwl10dRiBcPoacJr0qjx7Ai+yTjQvk31aws92JZ
Q1070mGsSQsS1uYWiJeDrCkGy+CZvnjFEUME7VaFaQAcXCCDyyBYA3NQGIY8ssgU7vqAxjB4EwA
DEIyxggQAsjxDBzRagKtbGaBXclAMMvNNuBaiGAAA7"

  return [image create photo -format GIF -data $logoData]
}


###
# main
###

makeWindow
doUpdateWidgets
::tk::PlaceWindow . widget

#############################################################################
#
# This file is licensed under the Cadence Public License Version 1.0 (the
# "License"), a copy of which is found in the included file named "LICENSE",
# and is distributed "AS IS." TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE
# LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO
# ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE.
# Please see the License for the full text of applicable terms.
#
#############################################################################
