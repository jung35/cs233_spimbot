# syscall constants
PRINT_STRING = 4
PRINT_CHAR   = 11
PRINT_INT    = 1

# debug constants
PRINT_INT_ADDR   = 0xffff0080
PRINT_FLOAT_ADDR = 0xffff0084
PRINT_HEX_ADDR   = 0xffff0088

# spimbot constants
VELOCITY       = 0xffff0010
ANGLE          = 0xffff0014
ANGLE_CONTROL  = 0xffff0018
BOT_X          = 0xffff0020
BOT_Y          = 0xffff0024
OTHER_BOT_X    = 0xffff00a0
OTHER_BOT_Y    = 0xffff00a4
TIMER          = 0xffff001c
SCORES_REQUEST = 0xffff1018

TILE_SCAN       = 0xffff0024
SEED_TILE       = 0xffff0054
WATER_TILE      = 0xffff002c
MAX_GROWTH_TILE = 0xffff0030
HARVEST_TILE    = 0xffff0020
BURN_TILE       = 0xffff0058
GET_FIRE_LOC    = 0xffff0028
PUT_OUT_FIRE    = 0xffff0040

GET_NUM_WATER_DROPS   = 0xffff0044
GET_NUM_SEEDS         = 0xffff0048
GET_NUM_FIRE_STARTERS = 0xffff004c
SET_RESOURCE_TYPE     = 0xffff00dc
REQUEST_PUZZLE        = 0xffff00d0
SUBMIT_SOLUTION       = 0xffff00d4

# interrupt constants
BONK_MASK               = 0x1000
BONK_ACK                = 0xffff0060
TIMER_MASK              = 0x8000
TIMER_ACK               = 0xffff006c
ON_FIRE_MASK            = 0x400
ON_FIRE_ACK             = 0xffff0050
MAX_GROWTH_ACK          = 0xffff005c
MAX_GROWTH_INT_MASK     = 0x2000
REQUEST_PUZZLE_ACK      = 0xffff00d8
REQUEST_PUZZLE_INT_MASK = 0x800

move_bot:
	sub 	$sp,	$sp,	24
	sw 	$ra,	0($sp)
	sw 	$s3,	4($sp)
	sw 	$s4,	8($sp)
	sw 	$s7,	12($sp)
	sw 	$s2,	16($sp)
	sw 	$s4,	20($sp)

	li 	$s7,	30
	mul 	$a0,	$a0,	$s7
	add 	$a0,	$a0,	15	# $a0 = 15 + x * 30
	mul 	$a1,	$a1,	$s7
	add 	$a1,	$a1,	15	# $a1 = 15 + y * 30
	lw 	$s2,	BOT_X 
	lw 	$s3,	BOT_Y

	# Put out fire!
	li	$s7, 	0
	sw 	$s7,	ANGLE
	
	li 	$s7, 	1
	sw 	$s7, 	ANGLE_CONTROL

xmove_loop:
	lw 	$s2,	BOT_X	
	sub 	$s4,	$a0,	$s2	# xdif
	beq 	$s4,	0,	xmove_endloop
	blt	$s4,	0,	xmove_negative
	li 	$s7,	10
	sw 	$s7,	VELOCITY
	j 	xmove_loop
	
xmove_negative:
	li 	$s7,	-10
	sw 	$s7,	VELOCITY
	j 	xmove_loop

xmove_endloop:

	# set angle to 90
	li	$s7, 	90
	sw 	$s7,	ANGLE

	li 	$s7, 	1
	sw 	$s7, 	ANGLE_CONTROL

ymove_loop:
	lw 	$s3,	BOT_Y
	sub 	$s4,	$a1,	$s3	# ydif
	beq 	$s4,	0,	ymove_endloop
	blt	$s4,	0,	ymove_negative
	li 	$s7,	10
	sw 	$s7,	VELOCITY
	j 	ymove_loop
	
ymove_negative:
	li 	$s7,	-10
	sw 	$s7,	VELOCITY
	j 	ymove_loop

ymove_endloop:
	sw 	$zero	VELOCITY

	lw 	$ra,	0($sp)
	lw 	$s3,	4($sp)
	lw 	$s4,	8($sp)
	lw 	$s7,	12($sp)
	lw 	$s2,	16($sp)
	lw 	$s4,	20($sp)
	add 	$sp,	$sp,	24
	jr 	$ra