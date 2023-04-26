package SongOfTheEarth
import "core:fmt"
import "core:strings"
import "core:intrinsics"
import "core:mem"
import "core:runtime"

// UI
UIDrawCommandCommon :: struct {

}

UIDrawCommandRect :: struct {
	rect: IntRect,

	color: Color,
}

UIDrawCommandText :: struct {
	begin: IntVector2,
	font: TTF_Font,
	text: string,

	color: Color,
}

UIDrawCommand :: union {
	UIDrawCommandRect,
	UIDrawCommandText,
}

MAX_ORIGIN_STACK_SIZE :: 256
MAX_CMD_STACK_SIZE :: 512
UIContext :: struct {
	origin_head: int, // @Default(0)
	origin_stack: [MAX_ORIGIN_STACK_SIZE]IntRect,

	cmd_head: int,
	cmd_stack: [MAX_CMD_STACK_SIZE]UIDrawCommand,

	// Style (user should directly edit these)
	color: Color,
	font: TTF_Font,
	margin: IntRect,
	rect_center: CenterOpts,
	text_center: CenterOpts,
}
CenterOpts :: bit_set[enum { HCenter, VCenter }]

@private contextual_rect_plus :: proc(ctx: ^UIContext, plus: IntRect) -> (IntRect) {
	ctx_rect: IntRect
	if ctx.origin_head <= 0 {
		ctx_rect = { 0, 0, 0, 0 }
	} else {
		ctx_rect = ctx.origin_stack[ctx.origin_head - 1]
	}

	ctx_rect.x += plus.x
	ctx_rect.y += plus.y
	ctx_rect.w = plus.w
	ctx_rect.h = plus.h
	return ctx_rect
}

@private push_cmd :: proc(ctx: ^UIContext, cmd: UIDrawCommand) {
	ctx.cmd_stack[ctx.cmd_head] = cmd
	ctx.cmd_head += 1
}

@private apply_margin :: proc(rect, margin: IntRect) -> (out: IntRect) {
	out.x = rect.x + margin.x
	out.y = rect.y + margin.y
	out.w = rect.w - (margin.w*2)
	out.h = rect.h - (margin.h*2)
	return
}

ui_begin :: proc(ctx: ^UIContext, alloc := context.temp_allocator) {
	ctx.origin_head = 0
	ctx.cmd_head = 0
}

ui_end :: proc(ctx: ^UIContext) {

}

ui_push_origin :: proc(ctx: ^UIContext, x, y: int) {
	assert(x > -1 && y > -1)
	assert(ctx != nil)

	ctx.origin_stack[ctx.origin_head] = contextual_rect_plus(ctx, IntRect{ x, y, 0, 0 })
	ctx.origin_head += 1
}

ui_pop_origin :: proc(ctx: ^UIContext) {
	ctx.origin_head -= 1
}

ui_rect :: proc(ctx: ^UIContext, x, y, w, h: int) {
	r := contextual_rect_plus(ctx, apply_margin(IntRect{ x, y, w, h }, ctx.margin))
	d_cmd := cast(UIDrawCommand) UIDrawCommandRect{
		rect = r,

		color = ctx.color,
	}

	push_cmd(ctx, d_cmd)
}

ui_text :: proc(ctx: ^UIContext, text: string, x, y: int) {
	r := contextual_rect_plus(ctx, apply_margin(IntRect{ x, y, 0, 0 }, ctx.margin))
	d_cmd := cast(UIDrawCommand) UIDrawCommandText{
		begin = { r.x, r.y },
		font = ctx.font,
		text = text,

		color = ctx.color,
	}

	push_cmd(ctx, d_cmd)
}




/// MENUS
PartyMenuLayer :: enum {
	Base,
		Create,
			Craft,
			Dismantle,
		SkillTree,
			SkillTreeTerry,
			SkillTreeViola,
			SkillTreeDex,
		Equip,
		Items,
			Battle,
			Components,
			Chemicals,
			KeyItems,
}

PartyMenuLayerStringNames := [PartyMenuLayer]string{
	.Base = "NIL",
		.Create = "UI_PARTYMENU_CREATE",
			.Craft = "UI_PARTYMENU_CRAFT",
			.Dismantle = "UI_PARTYMENU_DISMANTLE",
		.SkillTree = "UI_PARTYMENU_SKILLTREE",
			.SkillTreeTerry = "UI_TERRY",
			.SkillTreeViola = "UI_VIOLA",
			.SkillTreeDex = "UI_DEX",
		.Equip = "UI_PARTYMENU_EQUIP",
		.Items = "UI_PARTYMENU_ITEMS",
			.Battle = "UI_PARTYMENU_BATTLE",
			.Components = "UI_PARTYMENU_COMPONENTS",
			.Chemicals = "UI_PARTYMENU_CHEMICALS",
			.KeyItems = "UI_PARTYMENU_KEYITEMS",
}