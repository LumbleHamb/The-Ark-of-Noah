class_name BookPage
extends Control

## Base class for all pages in the pause menu.

func on_page_opened() -> void:
	# Called when this page becomes visible. Override for refresh logic.
	pass

func on_page_closed() -> void:
	# Called when navigating away from this page.
	pass
