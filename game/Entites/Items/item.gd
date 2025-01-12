class_name Item
extends Node3D

@onready var physical_instance = $Physical
@onready var equipped_instance = $Equipped

@onready var animation_player = $AnimationPlayer

var item_name: String
var model: ArrayMesh
var equippable: bool
var equipped: bool
var user: CharacterBody3D

func _ready():
    if get_parent().name == "WeaponContainer":
        print("equipped")
        equip()
    else:
        unequip()

func equip():
    equipped = true

    _toggle_state(physical_instance, "disabled")
    _toggle_state(equipped_instance, "enabled")


func unequip():
    equipped = false

    _toggle_state(physical_instance, "enabled")
    _toggle_state(equipped_instance, "disabled")


func _toggle_state(node: Node3D, state: String):
    if state == "enabled":
        node.visible = true
        node.set_process(true)
        node.set_physics_process(true)
        if node is CollisionShape3D:
            node.disabled = false
        
    elif state == "disabled":
        node.visible = false
        node.set_process(false)
        node.set_physics_process(false)
        if node is CollisionShape3D:
            node.disabled = true

    for child in node.get_children():
        _toggle_state(child, state)

func _on_animation_player_animation_finished(anim_name: StringName):
    if equipped:
        user.anim_ended(anim_name)
