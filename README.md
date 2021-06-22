PickDbByColor
==========================================
Copyright 2021 Cadence Design Systems, Inc. All rights reserved worldwide.

The PickDbByColor script provides a mechanism for you to select database
entities by their color and then apply a command to them.

Entities to be selected are governed by:

1. Line Color: This is the entities' secondary color, the one set in 
the Advanced frame of the Attributes command (Color 2).
2. Surface Color: This is the entities' primary color.
3. By checking "Include hidden entities" they may be acted upon as well.

The actions to be applied to these entities are:

1. They can be moved to a layer.
2. They can be enabled or disabled.
3. They can be added to a group.

Note that because this script is a Pointwise/Glyph 2 version of a 
Gridgen script, the nomenclature used may seem out of date.

![PickDbByColor-Tk](https://raw.github.com/pointwise/PickDbByColor/master/PickDbByColor-Tk.png)

Disclaimer
----------
This file is licensed under the Cadence Public License Version 1.0 (the "License"), a copy of which is found in the LICENSE file, and is distributed "AS IS." 
TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE. 
Please see the License for the full text of applicable terms.
