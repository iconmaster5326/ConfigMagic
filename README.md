Config Magic
============

Config Magic is a GUI application written in Lua that reads your Forge config files and automatically detects any ID conflicts. You can use this application to view all the block/item ID mappings from all your mods, and to find out exactly which ones have overlapping IDs.

Features
========

* Shows all the block and item IDs from your config files
* Detects conflicting IDs and displays them as red
* Double-click on an item to edit its ID or find out exactly what's conflicting with it
* Give items/block config names aliases for easy configuration

Installation
============

This program is written in Lua 5.1 using the IUP and LFS libraries. You will need the Lua executable and both of the libraries to run this program. I suggest installing Lua for Windows. Once you have Lua installed, all you have to do is run configmagic.lua.

Planned Features
================

* Custom searching in the list view
* Auto conflict resolution
* A free ID range finder
* Automatic compensation for the item ID +256 bug
* Config backups
* Much, much more!

Disclaimer
==========

This tool will never be exact at autodetection; some modders use inconsistent styles, and Config Magic can't detect these edge cases. Config Magic is not 100% capable of properly diagnosing ID conflicts; player discresion is still needed.