class_name BookPageComponent
extends Control

## ============================================================================
## BOOK PAGE COMPONENT — Base class for all pages in the rebuilt book menu.
##
## Each page is a Control that fills its book-page area and exposes:
##   - on_page_opened(): called when this page becomes the active spread
##   - on_page_closed(): called when navigating away
##   - page_title:       a designer-set title shown at the top of the page
##
## Pages live inside a PageContainer (clip_contents = true) so their content
## is constrained to the visible paper bounds — no icons spill outside.
## ============================================================================

signal page_opened()
signal page_closed()

## Title displayed at the top of the page (used by the controller for nav).
@export var page_title: String = "Page"

## Called by BookUIController when this page becomes visible.
func on_page_opened() -> void:
	page_opened.emit()

## Called by BookUIController when navigating away from this page.
func on_page_closed() -> void:
	page_closed.emit()
