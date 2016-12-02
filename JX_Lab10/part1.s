# syscall constants
PRINT_STRING	= 4
PRINT_CHAR	= 11
PRINT_INT	= 1

# memory-mapped I/O
VELOCITY	= 0xffff0010
ANGLE		= 0xffff0014
ANGLE_CONTROL	= 0xffff0018

BOT_X		= 0xffff0020
BOT_Y		= 0xffff0024

TIMER		= 0xffff001c

TILE_SCAN	= 0xffff0024
HARVEST_TILE	= 0xffff0020

GET_FIRE_LOC	= 0xffff0028
PUT_OUT_FIRE	= 0xffff0040

PRINT_INT_ADDR		= 0xffff0080
PRINT_FLOAT_ADDR	= 0xffff0084
PRINT_HEX_ADDR		= 0xffff0088

# interrupt constants
BONK_MASK	= 0x1000
BONK_ACK	= 0xffff0060

TIMER_MASK	= 0x8000
TIMER_ACK	= 0xffff006c

ON_FIRE_MASK	= 0x400
ON_FIRE_ACK	= 0xffff0050


.data
# put your data things here
.align 2
tile_data: .space 1600

.text
main:
	# put your code here :)

	la	$s0,	tile_data
	sw 	$s0,	TILE_SCAN
	 
	# for (int i = 0; i < 100; i++) {
	# 	if (tile_data[i].state) {
	#		harvest();
	#	}
	# }

	li 	$s1,	0		# i = 0
main_loop:
	bge 	$s1,	100,	main_endloop
	sll 	$s2,	$s1,	4	# i << 4
	add 	$s2,	$s2,	$s0	# &tile_data[i].state
	lw 	$s2,	0($s2) 		# tile_data[i].state
	beq 	$s2,	0,	main_endif
	
	# harvest
	# Now, x = i % 10, y = i / 10
	# The coordinate of the center of the tile is:
	# (15 + x * 30, 15 + y * 30)
	li 	$t0,	10
	div 	$s1,	$t0		# $HI = x, $LO = y
	li 	$t7,	30
	mfhi 	$t4
	mflo	$t5
	mul 	$t0,	$t4,	$t7
	add 	$t0,	$t0,	15	# $t0 = 15 + x * 30
	mul 	$t1,	$t5,	$t7
	add 	$t1,	$t1,	15	# $t1 = 15 + y * 30
	lw 	$t2,	BOT_X 
	lw 	$t3,	BOT_Y

	# int xdif = x - botx
	# int ydif = y - boty
	# while (xdif != 0) {
	# 	if (xdif > 0) {
	#		velocity = 10;
	li	$t7, 	0
	sw 	$t7,	ANGLE
	
	li 	$t7, 	1
	sw 	$t7, 	ANGLE_CONTROL

xmove_loop:
	lw 	$t2,	BOT_X	
	sub 	$t4,	$t0,	$t2	# xdif
	beq 	$t4,	0,	xmove_endloop
	blt	$t4,	0,	xmove_negative
	li 	$t7,	10
	sw 	$t7,	VELOCITY
	j 	xmove_loop
	
xmove_negative:
	li 	$t7,	-10
	sw 	$t7,	VELOCITY
	j 	xmove_loop

xmove_endloop:

	# set angle to 90
	li	$t7, 	90
	sw 	$t7,	ANGLE

	li 	$t7, 	1
	sw 	$t7, 	ANGLE_CONTROL

ymove_loop:
	lw 	$t3,	BOT_Y
	sub 	$t4,	$t1,	$t3	# ydif
	beq 	$t4,	0,	ymove_endloop
	blt	$t4,	0,	ymove_negative
	li 	$t7,	10
	sw 	$t7,	VELOCITY
	j 	ymove_loop
	
ymove_negative:
	li 	$t7,	-10
	sw 	$t7,	VELOCITY
	j 	ymove_loop

ymove_endloop:
	sw 	$t7 	HARVEST_TILE

	
main_endif:
	add 	$s1,	$s1,	1
	j 	main_loop
main_endloop:

	# note that we infinite loop to avoid stopping the simulation early
	j	main
	
