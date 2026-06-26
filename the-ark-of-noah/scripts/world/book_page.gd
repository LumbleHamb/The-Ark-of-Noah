class_name BookPage
extends Control

## Base class for all pages in the pause menu book overlay.

## Called when this page becomes visible. Override for refresh logic.
func on_page_opened() -> void:
	pass

## Called when navigating away from this page.
func on_page_closed() -> void:
	pass
