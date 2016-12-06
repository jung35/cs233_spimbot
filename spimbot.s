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


#########################################INTERRUPT HANDLER###########################################
.kdata				# interrupt handler data (separated just for readability)
chunkIH:	.space 88	# space for registers
non_intrpt_str:	.asciiz "Non-interrupt exception\n"
unhandled_str:	.asciiz "Unhandled interrupt type\n"

.ktext 0x80000180
interrupt_handler:
.set noat
	move	$k1, $at		# Save $at
.set at
	la	$k0, 	chunkIH
	sw	$a0, 	0($k0)		# Get some free registers
	sw	$a1, 	4($k0)		# by storing them to a global variable
	sw 	$t0,	8($k0)
	sw 	$t1,	12($k0)
	sw 	$t2,	16($k0)
	sw 	$t3,	20($k0)
	sw 	$t4,	24($k0)
	sw 	$t5,	28($k0)
	sw 	$t6,	32($k0)
	sw 	$t7,	36($k0)
    	sw  	$t8,    40($k0)
    	sw  	$t9,    44($k0)
	sw 	$v0,	48($k0)
    	sw  	$ra,    52($k0)
    	sw  	$s0,    56($k0)
    	sw  	$s1,    60($k0)
    	sw  	$s2,    64($k0)
    	sw  	$s3,    68($k0)
    	sw  	$s4,    72($k0)
    	sw  	$s5,    76($k0)
    	sw  	$s6,    80($k0)
    	sw  	$s7,    84($k0)

	mfc0	$k0, $13		# Get Cause register
	srl	$a0, $k0, 2
	and	$a0, $a0, 0xf		# ExcCode field
	bne	$a0, 0, non_intrpt

interrupt_dispatch:			# Interrupt:
	mfc0	$k0, $13		# Get Cause register, again
	beq	$k0, 0, done		# handled all outstanding interrupts

	#and	$a0, $k0, BONK_MASK	# is there a bonk interrupt?
	#bne	$a0, 0, bonk_interrupt

	#and	$a0, $k0, TIMER_MASK	# is there a timer interrupt?
	#bne	$a0, 0, timer_interrupt

	and	$a0,	$k0,	ON_FIRE_MASK	# is there an on_fire interrupt?
	bne 	$a0,	0,	on_fire_interrupt

	and 	$a0,	$k0,	REQUEST_PUZZLE_INT_MASK
	bne 	$a0,	0,	puzzle_interrupt

	and    	$a0, 	$k0, 	MAX_GROWTH_INT_MASK
    	bne     $a0,    0,  	max_growth_interrupt

	# add dispatch for other interrupt types here.

	li	$v0, PRINT_STRING	# Unhandled interrupt types
	la	$a0, unhandled_str
	syscall
	j	done

puzzle_interrupt:
	sw	$a1,	REQUEST_PUZZLE_ACK	# acknowledge interrupt

	# Set PENDING_PUZZLE to 1
	li 	$t0,	1
	la 	$t1,	PENDING_PUZZLE
	sw 	$t0,	0($t1)


	j	interrupt_dispatch	# see if other interrupts are waiting


on_fire_interrupt:
	sw	$a1,	ON_FIRE_ACK		# acknowledge interrupt

	lw 	$a1,	GET_FIRE_LOC
	srl 	$t0,	$a1,	16		# $t0 = fire location x index
	and 	$t1,	$a1,	0x0000ffff	# $t1 = fire location y index

    move    $a0, $t0
    move    $a1, $t1
    jal int_bot_move

    sw  $zero, PUT_OUT_FIRE
	j	interrupt_dispatch	# see if other interrupts are waiting

max_growth_interrupt:
    sw  $a1,    MAX_GROWTH_ACK     # acknowledge interrupt

    # lw  	$a1,    MAX_GROWTH_TILE
    # srl     $t0,    $a1,    16      # $t0 = growth location x index
    # and     $t1,    $a1,    0x0000ffff  # $t1 = growth location y index


    # move    $a0, $t0
    # move    $a1, $t1
    # jal int_bot_move
    li	$t3,	1
    sw	$t3,	MAX_GROWTH


    j   interrupt_dispatch  # see if other interrupts are waiting


non_intrpt:				# was some non-interrupt
	li	$v0, PRINT_STRING
	la	$a0, non_intrpt_str
	syscall				# print out an error message
	# fall through to done

done:
	la	$k0, 	chunkIH
	lw	$a0, 	0($k0)		# Restore saved registers
	lw	$a1, 	4($k0)
	lw 	$t0,	8($k0)
	lw 	$t1,	12($k0)
	lw 	$t2,	16($k0)
	lw 	$t3,	20($k0)
	lw 	$t4,	24($k0)
	lw 	$t5,	28($k0)
	lw 	$t6,	32($k0)
	lw 	$t7,	36($k0)
    	lw  	$t8,    40($k0)
    	lw  	$t9,    44($k0)
	lw 	$v0,	48($k0)
    	lw  	$ra,    52($k0)
    	lw  	$s0,    56($k0)
    	lw  	$s1,    60($k0)
    	lw  	$s2,    64($k0)
    	lw  	$s3,    68($k0)
    	lw  	$s4,    72($k0)
    	lw  	$s5,    76($k0)
    	lw  	$s6,    80($k0)
    	lw  	$s7,    84($k0)
.set noat
	move	$at, $k1		# Restore $at
.set at
	eret


int_bot_move:
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

xmove_loop2:
	lw 	$s2,	BOT_X
	sub 	$s4,	$a0,	$s2	# xdif
	beq 	$s4,	0,	xmove_endloop2
	blt	$s4,	0,	xmove_negative2
	li 	$s7,	10
	sw 	$s7,	VELOCITY
	j 	xmove_loop2

xmove_negative2:
	li 	$s7,	-10
	sw 	$s7,	VELOCITY
	j 	xmove_loop2

xmove_endloop2:

	# set angle to 90
	li	$s7, 	90
	sw 	$s7,	ANGLE

	li 	$s7, 	1
	sw 	$s7, 	ANGLE_CONTROL

ymove_loop2:
	lw 	$s3,	BOT_Y
	sub 	$s4,	$a1,	$s3	# ydif
	beq 	$s4,	0,	ymove_endloop2
	blt	$s4,	0,	ymove_negative2
	li 	$s7,	10
	sw 	$s7,	VELOCITY
	j 	ymove_loop2

ymove_negative2:
	li 	$s7,	-10
	sw 	$s7,	VELOCITY
	j 	ymove_loop2

ymove_endloop2:
	sw 	$s7 	PUT_OUT_FIRE
	sw 	$zero	VELOCITY

	lw 	$ra,	0($sp)
	lw 	$s3,	4($sp)
	lw 	$s4,	8($sp)
	lw 	$s7,	12($sp)
	lw 	$s2,	16($sp)
	lw 	$s4,	20($sp)
	add 	$sp,	$sp,	24
	jr 	$ra

#########################################MAIN###########################################
.data
# put your data things here

.align 2
tile_data: .space 1600
puzzle_data: .space 8192
solution_data: .space 328
PENDING_PUZZLE: .space 4
MAX_GROWTH: .space 4



.text
main:
    	sw  	$zero, 	SEED_TILE
	sw	$0,	MAX_GROWTH
    	la      $t0, 	tile_data
    	sw      $t0, 	TILE_SCAN
	# go wild
	# the world is your oyster :)

	# Enable interrupts
	li	$t4, 	ON_FIRE_MASK	# on fire interrupt enable bit
    	or  	$t4,    REQUEST_PUZZLE_INT_MASK
    	or  	$t4,    MAX_GROWTH_INT_MASK
	or	$t4, 	$t4, 1		# global interrupt enable
	mtc0	$t4, 	$12		# set interrupt mask (Status register)

	# # send 5 seed requests
	# li 	$t0,	0		# i
	# li 	$t1,	5		# 5 puzzle for 15 seeds
	# li 	$t2,	1		# type = seed # 0 for water, 1 for seeds, 2 for fire starters
	# sw 	$t2,	SET_RESOURCE_TYPE


infinite:
	# Check resources
	lw	$t0,	MAX_GROWTH
	beq 	$t0,	0,	harvest_skip
	jal 	harvest_all
	j	infinite
harvest_skip:

	lw  $t0, GET_NUM_SEEDS
    bge $t0, 20, checkNumFireStarters
	li  $t1, 1  # 0 for water, 1 for seeds, 2 for fire starters
    sw  $t1,    SET_RESOURCE_TYPE
    la  $t0,    puzzle_data
    sw  $t0,    REQUEST_PUZZLE
wait:
	lw 	$t0,	PENDING_PUZZLE
	beq	$t0,	0,	wait
	jal	solve_puzzle

    j   noPuzzleRequest
checkNumFireStarters:
   lw  $t0, GET_NUM_FIRE_STARTERS
   bgt $t0, 1, checkNumWater
   li  $t1, 2
   sw  $t1,    SET_RESOURCE_TYPE
   la  $t0,    puzzle_data
   sw  $t0,    REQUEST_PUZZLE
wait2:
   lw 	$t0,	PENDING_PUZZLE
   beq	$t0,	0,	wait2
   jal	solve_puzzle

checkNumWater: # need to put out water
   lw  $t0, GET_NUM_WATER_DROPS
   bge $t0, 10, noPuzzleRequest
   li  $t1, 0
   sw  $t1,    SET_RESOURCE_TYPE
   la  $t0,    puzzle_data
   sw  $t0,    REQUEST_PUZZLE
wait3:
      lw 	$t0,	PENDING_PUZZLE
      beq	$t0,	0,	wait3
      jal	solve_puzzle
noPuzzleRequest:
	# Sequentially checks the four tiles around it. If the tile is empty, go there and plant.
	# If current tile is not seeded. Seed it.
	lw 	$s0,	BOT_X
	lw 	$s1, 	BOT_Y

	div 	$a0,	$s0,	30	# xcoord
	div	$a1,	$s1,	30	# ycoord
	jal 	check_set_fire
	beq 	$v0,	0,	set_fire_skip
	sw	$0,	BURN_TILE
set_fire_skip:
	div 	$a0,	$s0,	30	# xcoord
	div	$a1,	$s1,	30	# ycoord
	jal 	check_empty
	bne 	$v0,	0,	seed_skip
	sw 	$0,	SEED_TILE
seed_skip:
	# if (x + 1 is empty) goto x + 1
	div 	$a0,	$s0,	30	# xcoord
	div	$a1,	$s1,	30	# ycoord
	add 	$a0,	$a0,	1	# x + 1
	jal 	check_empty
	bne 	$v0,	0,	xplus1_skip
	jal 	check_set_fire
	beq 	$v0,	0,	xplus1_skip
	div 	$a0,	$s0,	30	# xcoord
	div	$a1,	$s1,	30	# ycoord
	add 	$a0,	$a0,	1	# x + 1
	jal 	move_bot
	j 	infinite
xplus1_skip:
	# if (x - 1 is empty) goto x - 1
	div 	$a0,	$s0,	30	# xcoord
	div	$a1,	$s1,	30	# ycoord
	sub 	$a0,	$a0,	1	# x - 1
	jal 	check_empty
	bne 	$v0,	0,	xminus1_skip
	jal 	check_set_fire
	beq 	$v0,	0,	xminus1_skip
	div 	$a0,	$s0,	30	# xcoord
	div	$a1,	$s1,	30	# ycoord
	sub 	$a0,	$a0,	1	# x - 1
	jal 	move_bot
	j 	infinite
xminus1_skip:
	# if (y + 1 is empty) goto y + 1
	div 	$a0,	$s0,	30	# xcoord
	div	$a1,	$s1,	30	# ycoord
	add 	$a1,	$a1,	1	# y + 1
	jal 	check_empty
	bne 	$v0,	0,	yplus1_skip
	jal 	check_set_fire
	beq 	$v0,	0,	yplus1_skip
	div 	$a0,	$s0,	30	# xcoord
	div	$a1,	$s1,	30	# ycoord
	add 	$a1,	$a1,	1	# y + 1
	jal 	move_bot
	j 	infinite
yplus1_skip:
	# if (y - 1 is empty) goto y + 1
	div 	$a0,	$s0,	30	# xcoord
	div	$a1,	$s1,	30	# ycoord
	sub 	$a1,	$a1,	1	# y - 1
	jal 	check_empty
	bne 	$v0,	0,	yminus1_skip
	jal 	check_set_fire
	beq 	$v0,	0,	yminus1_skip
	div 	$a0,	$s0,	30	# xcoord
	div	$a1,	$s1,	30	# ycoord
	sub 	$a1,	$a1,	1	# y - 1
	jal 	move_bot
	j 	infinite
yminus1_skip:
	li	$a0,	0
	li	$a1,	0
	jal 	move_bot

	j 	infinite

#########################################FUNCTIONS###########################################
harvest_all:
        sub     $sp,    $sp,    16
        sw      $ra,    0($sp)
        sw      $s0,    4($sp)
        sw      $s1,    8($sp)
        sw      $s2,    12($sp)

        la	$s0,	tile_data
        sw 	$s0,	TILE_SCAN
	li	$s1,	0
harvest_loop:
	bge 	$s1,	100,	harvest_endloop
	sll 	$s2,	$s1,	4	# i << 4
	add 	$s2,	$s2,	$s0	# &tile_data[i].state
	lw 	$s2,	0($s2) 		# tile_data[i].state
	beq 	$s2,	0,	harvest_endif

        li 	$t0,	10
        div 	$s1,	$t0		# $HI = x, $LO = y
        mfhi 	$a0
        mflo	$a1
        jal     move_bot
        sw      $0,     HARVEST_TILE
harvest_endif:
        add 	$s1,	$s1,	1
        j 	harvest_loop
harvest_endloop:
	sw	$0,	MAX_GROWTH

        lw      $ra,    0($sp)
        lw      $s0,    4($sp)
        lw      $s1,    8($sp)
        lw      $s2,    12($sp)
        add     $sp,    $sp,    16
        jr      $ra

check_empty:
	# $a0 = x, $a1 = y;
	sub 	$sp,	$sp,	20
	sw 	$ra,	0($sp)
	sw 	$s0,	4($sp)
	sw 	$s1,	8($sp)
	sw 	$s2,	12($sp)

	li 	$v0,	1
	bge 	$a0,	10, 	ce_return	# if x > 10 return 0
	blt 	$a0,	0,	ce_return
	bge 	$a1,	10,	ce_return
	blt 	$a1,	0,	ce_return

	la      $s1, 	tile_data	# &tile_data
    	sw      $s1, 	TILE_SCAN
    	# index in tile_data = x + y * 10
    	mul 	$s0,	$a1,	10
    	add 	$s0,	$a0,	$s0 	# x + y * 10
    	sll 	$s0,	$s0,	4	# index * 16(TileInfo size)
    	add 	$t0,	$s1,	$s0
    	lw 	$v0,	0($t0)		# state
ce_return:
    	lw 	$ra,	0($sp)
	lw 	$s0,	4($sp)
	lw 	$s1,	8($sp)
	lw 	$s2,	12($sp)
	add 	$sp,	$sp,	20
	jr 	$ra

check_set_fire:
	# $a0 = x, $a1 = y;
	sub 	$sp,	$sp,	20
	sw 	$ra,	0($sp)
	sw 	$s0,	4($sp)
	sw 	$s1,	8($sp)
	sw 	$s2,	12($sp)

	li 	$v0,	1
	bge 	$a0,	10, 	csf_return	# if x > 10 return 0
	blt 	$a0,	0,	csf_return
	bge 	$a1,	10,	csf_return
	blt 	$a1,	0,	csf_return

	la      $s1, 	tile_data	# &tile_data
    	sw      $s1, 	TILE_SCAN
    	# index in tile_data = x + y * 10
    	mul 	$s0,	$a1,	10
    	add 	$s0,	$a0,	$s0 	# x + y * 10
    	sll 	$s0,	$s0,	4	# index * 16(TileInfo size)
    	add 	$t0,	$s1,	$s0
    	lw 	$v0,	4($t0)		# owner
csf_return:
    	lw 	$ra,	0($sp)
	lw 	$s0,	4($sp)
	lw 	$s1,	8($sp)
	lw 	$s2,	12($sp)
	add 	$sp,	$sp,	20
	jr 	$ra




solve_puzzle:
	sub 	$sp,	$sp,	20
	sw 	$ra,	0($sp)
	sw 	$s0,	4($sp)
	sw 	$s1,	8($sp)
	sw 	$s2,	12($sp)

	la 	$t0,	PENDING_PUZZLE
	lw 	$t0,	0($t0)
	bne 	$t0,	1,	pi_end

	li 	$s0,	0
	la 	$s1,	solution_data
pi_loop:
	bge 	$s0,	328,	pi_endloop
	sll 	$s2,	$s0,	2		#t0 << 2
	add 	$s2,	$s2,	$s1
	sw 	$0,	0($s2)
	add 	$s0,	$s0,	1
	j 	pi_loop
pi_endloop:

	la	$a0, 	solution_data
	la	$a1, 	puzzle_data
	jal	recursive_backtracking

	la 	$s0,	solution_data
	sw	$s0,	SUBMIT_SOLUTION

	# Set PENDING_PUZZLE to 0;
	li 	$s0,	0
	la 	$s1,	PENDING_PUZZLE
	sw 	$s0,	0($s1)

pi_end:
	lw 	$ra,	0($sp)
	lw 	$s0,	4($sp)
	lw 	$s1,	8($sp)
	lw 	$s2,	12($sp)
	add 	$sp,	$sp,	20
	jr 	$ra

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

	li	$s7, 	0
	sw 	$s7,	ANGLE

	li 	$s7, 	1
	sw 	$s7, 	ANGLE_CONTROL

xmove_loop:
	lw 	$s2,	BOT_X

# 	li 	$t0,	30
# 	div 	$s2,	$t0		# $HI = x, $LO = y
# 	mfhi 	$t1
# 	# if x % 30 == 15 we check if the tile has an enemy plant, and burn it if it does.
# 	bne 	$t1,	15,	burn_move_skip
# 	div 	$a0,	$s0,	30	# xcoord
# 	div	$a1,	$s1,	30	# ycoord
# 	jal 	check_set_fire
# 	bne 	$v0,	0,	burn_move_skip
# 	sw	$0,	BURN_TILE
# burn_move_skip:
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

.globl recursive_backtracking
recursive_backtracking:
  sub   $sp, $sp, 680
  sw    $ra, 0($sp)
  sw    $a0, 4($sp)     # solution
  sw    $a1, 8($sp)     # puzzle
  sw    $s0, 12($sp)    # position
  sw    $s1, 16($sp)    # val
  sw    $s2, 20($sp)    # 0x1 << (val - 1)
                        # sizeof(Puzzle) = 8
                        # sizeof(Cell [81]) = 648

  jal   is_complete
  bne   $v0, $0, recursive_backtracking_return_one
  lw    $a0, 4($sp)     # solution
  lw    $a1, 8($sp)     # puzzle
  jal   get_unassigned_position
  move  $s0, $v0        # position
  li    $s1, 1          # val = 1
recursive_backtracking_for_loop:
  lw    $a0, 4($sp)     # solution
  lw    $a1, 8($sp)     # puzzle
  lw    $t0, 0($a1)     # puzzle->size
  add   $t1, $t0, 1     # puzzle->size + 1
  bge   $s1, $t1, recursive_backtracking_return_zero  # val < puzzle->size + 1
  lw    $t1, 4($a1)     # puzzle->grid
  mul   $t4, $s0, 8     # sizeof(Cell) = 8
  add   $t1, $t1, $t4   # &puzzle->grid[position]
  lw    $t1, 0($t1)     # puzzle->grid[position].domain
  sub   $t4, $s1, 1     # val - 1
  li    $t5, 1
  sll   $s2, $t5, $t4   # 0x1 << (val - 1)
  and   $t1, $t1, $s2   # puzzle->grid[position].domain & (0x1 << (val - 1))
  beq   $t1, $0, recursive_backtracking_for_loop_continue # if (domain & (0x1 << (val - 1)))
  mul   $t0, $s0, 4     # position * 4
  add   $t0, $t0, $a0
  add   $t0, $t0, 4     # &solution->assignment[position]
  sw    $s1, 0($t0)     # solution->assignment[position] = val
  lw    $t0, 0($a0)     # solution->size
  add   $t0, $t0, 1
  sw    $t0, 0($a0)     # solution->size++
  add   $t0, $sp, 32    # &grid_copy
  sw    $t0, 28($sp)    # puzzle_copy.grid = grid_copy !!!
  move  $a0, $a1        # &puzzle
  add   $a1, $sp, 24    # &puzzle_copy
  jal   clone           # clone(puzzle, &puzzle_copy)
  mul   $t0, $s0, 8     # !!! grid size 8
  lw    $t1, 28($sp)

  add   $t1, $t1, $t0   # &puzzle_copy.grid[position]
  sw    $s2, 0($t1)     # puzzle_copy.grid[position].domain = 0x1 << (val - 1);
  move  $a0, $s0
  add   $a1, $sp, 24
  jal   forward_checking  # forward_checking(position, &puzzle_copy)
  beq   $v0, $0, recursive_backtracking_skip

  lw    $a0, 4($sp)     # solution
  add   $a1, $sp, 24    # &puzzle_copy
  jal   recursive_backtracking
  beq   $v0, $0, recursive_backtracking_skip
  j     recursive_backtracking_return_one # if (recursive_backtracking(solution, &puzzle_copy))
recursive_backtracking_skip:
  lw    $a0, 4($sp)     # solution
  mul   $t0, $s0, 4
  add   $t1, $a0, 4
  add   $t1, $t1, $t0
  sw    $0, 0($t1)      # solution->assignment[position] = 0
  lw    $t0, 0($a0)
  sub   $t0, $t0, 1
  sw    $t0, 0($a0)     # solution->size -= 1
recursive_backtracking_for_loop_continue:
  add   $s1, $s1, 1     # val++
  j     recursive_backtracking_for_loop
recursive_backtracking_return_zero:
  li    $v0, 0
  j     recursive_backtracking_return
recursive_backtracking_return_one:
  li    $v0, 1
recursive_backtracking_return:
  lw    $ra, 0($sp)
  lw    $a0, 4($sp)
  lw    $a1, 8($sp)
  lw    $s0, 12($sp)
  lw    $s1, 16($sp)
  lw    $s2, 20($sp)
  add   $sp, $sp, 680
  jr    $ra



.globl is_complete
is_complete:
  lw    $t0, 0($a0)       # solution->size
  lw    $t1, 0($a1)       # puzzle->size
  mul   $t1, $t1, $t1     # puzzle->size * puzzle->size
  move	$v0, $0
  seq   $v0, $t0, $t1
  j     $ra


.globl get_unassigned_position
get_unassigned_position:
  li    $v0, 0            # unassigned_pos = 0
  lw    $t0, 0($a1)       # puzzle->size
  mul  $t0, $t0, $t0     # puzzle->size * puzzle->size
  add   $t1, $a0, 4       # &solution->assignment[0]
get_unassigned_position_for_begin:
  bge   $v0, $t0, get_unassigned_position_return  # if (unassigned_pos < puzzle->size * puzzle->size)
  mul  $t2, $v0, 4
  add   $t2, $t1, $t2     # &solution->assignment[unassigned_pos]
  lw    $t2, 0($t2)       # solution->assignment[unassigned_pos]
  beq   $t2, 0, get_unassigned_position_return  # if (solution->assignment[unassigned_pos] == 0)
  add   $v0, $v0, 1       # unassigned_pos++
  j   get_unassigned_position_for_begin
get_unassigned_position_return:
  jr    $ra


.globl forward_checking
forward_checking:
  sub   $sp, $sp, 24
  sw    $ra, 0($sp)
  sw    $a0, 4($sp)
  sw    $a1, 8($sp)
  sw    $s0, 12($sp)
  sw    $s1, 16($sp)
  sw    $s2, 20($sp)
  lw    $t0, 0($a1)     # size
  li    $t1, 0          # col = 0
fc_for_col:
  bge   $t1, $t0, fc_end_for_col  # col < size
  div   $a0, $t0
  mfhi  $t2             # position % size
  mflo  $t3             # position / size
  beq   $t1, $t2, fc_for_col_continue    # if (col != position % size)
  mul   $t4, $t3, $t0
  add   $t4, $t4, $t1   # position / size * size + col
  mul   $t4, $t4, 8
  lw    $t5, 4($a1) # puzzle->grid
  add   $t4, $t4, $t5   # &puzzle->grid[position / size * size + col].domain
  mul   $t2, $a0, 8   # position * 8
  add   $t2, $t5, $t2 # puzzle->grid[position]
  lw    $t2, 0($t2) # puzzle -> grid[position].domain
  not   $t2, $t2        # ~puzzle->grid[position].domain
  lw    $t3, 0($t4) #
  and   $t3, $t3, $t2
  sw    $t3, 0($t4)
  beq   $t3, $0, fc_return_zero # if (!puzzle->grid[position / size * size + col].domain)
fc_for_col_continue:
  add   $t1, $t1, 1     # col++
  j     fc_for_col
fc_end_for_col:
  li    $t1, 0          # row = 0
fc_for_row:
  bge   $t1, $t0, fc_end_for_row  # row < size
  div   $a0, $t0
  mflo  $t2             # position / size
  mfhi  $t3             # position % size
  beq   $t1, $t2, fc_for_row_continue
  lw    $t2, 4($a1)     # puzzle->grid
  mul   $t4, $t1, $t0
  add   $t4, $t4, $t3
  mul   $t4, $t4, 8
  add   $t4, $t2, $t4   # &puzzle->grid[row * size + position % size]
  lw    $t6, 0($t4)
  mul   $t5, $a0, 8
  add   $t5, $t2, $t5
  lw    $t5, 0($t5)     # puzzle->grid[position].domain
  not   $t5, $t5
  and   $t5, $t6, $t5
  sw    $t5, 0($t4)
  beq   $t5, $0, fc_return_zero
fc_for_row_continue:
  add   $t1, $t1, 1     # row++
  j     fc_for_row
fc_end_for_row:

  li    $s0, 0          # i = 0
fc_for_i:
  lw    $t2, 4($a1)
  mul   $t3, $a0, 8
  add   $t2, $t2, $t3
  lw    $t2, 4($t2)     # &puzzle->grid[position].cage
  lw    $t3, 8($t2)     # puzzle->grid[position].cage->num_cell
  bge   $s0, $t3, fc_return_one
  lw    $t3, 12($t2)    # puzzle->grid[position].cage->positions
  mul   $s1, $s0, 4
  add   $t3, $t3, $s1
  lw    $t3, 0($t3)     # pos
  lw    $s1, 4($a1)
  mul   $s2, $t3, 8
  add   $s2, $s1, $s2   # &puzzle->grid[pos].domain
  lw    $s1, 0($s2)
  move  $a0, $t3
  jal get_domain_for_cell
  lw    $a0, 4($sp)
  lw    $a1, 8($sp)
  and   $s1, $s1, $v0
  sw    $s1, 0($s2)     # puzzle->grid[pos].domain &= get_domain_for_cell(pos, puzzle)
  beq   $s1, $0, fc_return_zero
fc_for_i_continue:
  add   $s0, $s0, 1     # i++
  j     fc_for_i
fc_return_one:
  li    $v0, 1
  j     fc_return
fc_return_zero:
  li    $v0, 0
fc_return:
  lw    $ra, 0($sp)
  lw    $a0, 4($sp)
  lw    $a1, 8($sp)
  lw    $s0, 12($sp)
  lw    $s1, 16($sp)
  lw    $s2, 20($sp)
  add   $sp, $sp, 24
  jr    $ra



.globl convert_highest_bit_to_int
convert_highest_bit_to_int:
    move  $v0, $0             # result = 0

chbti_loop:
    beq   $a0, $0, chbti_end
    add   $v0, $v0, 1         # result ++
    sra   $a0, $a0, 1         # domain >>= 1
    j     chbti_loop

chbti_end:
    jr    $ra

.globl is_single_value_domain
is_single_value_domain:
    beq    $a0, $0, isvd_zero     # return 0 if domain == 0
    sub    $t0, $a0, 1	          # (domain - 1)
    and    $t0, $t0, $a0          # (domain & (domain - 1))
    bne    $t0, $0, isvd_zero     # return 0 if (domain & (domain - 1)) != 0
    li     $v0, 1
    jr	   $ra

isvd_zero:
    li	   $v0, 0
    jr	   $ra

.globl get_domain_for_addition
get_domain_for_addition:
    sub    $sp, $sp, 20
    sw     $ra, 0($sp)
    sw     $s0, 4($sp)
    sw     $s1, 8($sp)
    sw     $s2, 12($sp)
    sw     $s3, 16($sp)
    move   $s0, $a0                     # s0 = target
    move   $s1, $a1                     # s1 = num_cell
    move   $s2, $a2                     # s2 = domain

    move   $a0, $a2
    jal    convert_highest_bit_to_int
    move   $s3, $v0                     # s3 = upper_bound

    sub    $a0, $0, $s2                 # -domain
    and    $a0, $a0, $s2                # domain & (-domain)
    jal    convert_highest_bit_to_int   # v0 = lower_bound

    sub    $t0, $s1, 1                  # num_cell - 1
    mul    $t0, $t0, $v0                # (num_cell - 1) * lower_bound
    sub    $t0, $s0, $t0                # t0 = high_bits
    bge    $t0, 0, gdfa_skip0

    li     $t0, 0

gdfa_skip0:
    bge    $t0, $s3, gdfa_skip1

    li     $t1, 1
    sll    $t0, $t1, $t0                # 1 << high_bits
    sub    $t0, $t0, 1                  # (1 << high_bits) - 1
    and    $s2, $s2, $t0                # domain & ((1 << high_bits) - 1)

gdfa_skip1:
    sub    $t0, $s1, 1                  # num_cell - 1
    mul    $t0, $t0, $s3                # (num_cell - 1) * upper_bound
    sub    $t0, $s0, $t0                # t0 = low_bits
    ble    $t0, $0, gdfa_skip2

    sub    $t0, $t0, 1                  # low_bits - 1
    sra    $s2, $s2, $t0                # domain >> (low_bits - 1)
    sll    $s2, $s2, $t0                # domain >> (low_bits - 1) << (low_bits - 1)

gdfa_skip2:
    move   $v0, $s2                     # return domain
    lw     $ra, 0($sp)
    lw     $s0, 4($sp)
    lw     $s1, 8($sp)
    lw     $s2, 12($sp)
    lw     $s3, 16($sp)
    add    $sp, $sp, 20
    jr     $ra

#loop_4ever:
   # j loop_4ever

    # And don't forget to delete the infinite loop :)


.globl get_domain_for_subtraction
get_domain_for_subtraction:

    # We highly recommend that you copy in our
    # solution when it is released on Tuesday night
    # after the late deadline for Lab7.2
    #
    # If you reach this part before Tuesday night,
    # you can paste your Lab7.2 solution here for now

#loop_5ever:
   # j loop_5ever

    # And don't forget to delete the infinite loop :)
    li     $t0, 1
    li     $t1, 2
    mul    $t1, $t1, $a0            # target * 2
    sll    $t1, $t0, $t1            # 1 << (target * 2)
    or     $t0, $t0, $t1            # t0 = base_mask
    li     $t1, 0                   # t1 = mask

gdfs_loop:
    beq    $a2, $0, gdfs_loop_end
    and    $t2, $a2, 1              # other_domain & 1
    beq    $t2, $0, gdfs_if_end

    sra    $t2, $t0, $a0            # base_mask >> target
    or     $t1, $t1, $t2            # mask |= (base_mask >> target)

gdfs_if_end:
    sll    $t0, $t0, 1              # base_mask <<= 1
    sra    $a2, $a2, 1              # other_domain >>= 1
    j      gdfs_loop

gdfs_loop_end:
    and    $v0, $a1, $t1            # domain & mask
    jr	   $ra



.globl get_domain_for_cell
get_domain_for_cell:
    # save registers
    sub $sp, $sp, 36
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
    sw $s4, 20($sp)
    sw $s5, 24($sp)
    sw $s6, 28($sp)
    sw $s7, 32($sp)

    li $t0, 0 # valid_domain
    lw $t1, 4($a1) # puzzle->grid (t1 free)
    sll $t2, $a0, 3 # position*8 (actual offset) (t2 free)
    add $t3, $t1, $t2 # &puzzle->grid[position]
    lw  $t4, 4($t3) # &puzzle->grid[position].cage
    lw  $t5, 0($t4) # puzzle->grid[posiition].cage->operation

    lw $t2, 4($t4) # puzzle->grid[position].cage->target

    move $s0, $t2   # remain_target = $s0  *!*!
    lw $s1, 8($t4) # remain_cell = $s1 = puzzle->grid[position].cage->num_cell
    lw $s2, 0($t3) # domain_union = $s2 = puzzle->grid[position].domain
    move $s3, $t4 # puzzle->grid[position].cage
    li $s4, 0   # i = 0
    move $s5, $t1 # $s5 = puzzle->grid
    move $s6, $a0 # $s6 = position
    # move $s7, $s2 # $s7 = puzzle->grid[position].domain

    bne $t5, 0, gdfc_check_else_if

    li $t1, 1
    sub $t2, $t2, $t1 # (puzzle->grid[position].cage->target-1)
    sll $v0, $t1, $t2 # valid_domain = 0x1 << (prev line comment)
    j gdfc_end # somewhere!!!!!!!!

gdfc_check_else_if:
    bne $t5, '+', gdfc_check_else

gdfc_else_if_loop:
    lw $t5, 8($s3) # puzzle->grid[position].cage->num_cell
    bge $s4, $t5, gdfc_for_end # branch if i >= puzzle->grid[position].cage->num_cell
    sll $t1, $s4, 2 # i*4
    lw $t6, 12($s3) # puzzle->grid[position].cage->positions
    add $t1, $t6, $t1 # &puzzle->grid[position].cage->positions[i]
    lw $t1, 0($t1) # pos = puzzle->grid[position].cage->positions[i]
    add $s4, $s4, 1 # i++

    sll $t2, $t1, 3 # pos * 8
    add $s7, $s5, $t2 # &puzzle->grid[pos]
    lw  $s7, 0($s7) # puzzle->grid[pos].domain

    beq $t1, $s6 gdfc_else_if_else # branch if pos == position



    move $a0, $s7 # $a0 = puzzle->grid[pos].domain
    jal is_single_value_domain
    bne $v0, 1 gdfc_else_if_else # branch if !is_single_value_domain()
    move $a0, $s7
    jal convert_highest_bit_to_int
    sub $s0, $s0, $v0 # remain_target -= convert_highest_bit_to_int
    addi $s1, $s1, -1 # remain_cell -= 1
    j gdfc_else_if_loop
gdfc_else_if_else:
    or $s2, $s2, $s7 # domain_union |= puzzle->grid[pos].domain
    j gdfc_else_if_loop

gdfc_for_end:
    move $a0, $s0
    move $a1, $s1
    move $a2, $s2
    jal get_domain_for_addition # $v0 = valid_domain = get_domain_for_addition()
    j gdfc_end

gdfc_check_else:
    lw $t3, 12($s3) # puzzle->grid[position].cage->positions
    lw $t0, 0($t3) # puzzle->grid[position].cage->positions[0]
    lw $t1, 4($t3) # puzzle->grid[position].cage->positions[1]
    xor $t0, $t0, $t1
    xor $t0, $t0, $s6 # other_pos = $t0 = $t0 ^ position
    lw $a0, 4($s3) # puzzle->grid[position].cage->target

    sll $t2, $s6, 3 # position * 8
    add $a1, $s5, $t2 # &puzzle->grid[position]
    lw  $a1, 0($a1) # puzzle->grid[position].domain
    # move $a1, $s7

    sll $t1, $t0, 3 # other_pos*8 (actual offset)
    add $t3, $s5, $t1 # &puzzle->grid[other_pos]
    lw $a2, 0($t3)  # puzzle->grid[other_pos].domian

    jal get_domain_for_subtraction # $v0 = valid_domain = get_domain_for_subtraction()
    # j gdfc_end
gdfc_end:
# restore registers

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp)
    lw $s5, 24($sp)
    lw $s6, 28($sp)
    lw $s7, 32($sp)
    add $sp, $sp, 36
    jr $ra


.globl clone
clone:

    lw  $t0, 0($a0)
    sw  $t0, 0($a1)

    mul $t0, $t0, $t0
    mul $t0, $t0, 2 # two words in one grid

    lw  $t1, 4($a0) # &puzzle(ori).grid
    lw  $t2, 4($a1) # &puzzle(clone).grid

    li  $t3, 0 # i = 0;
clone_for_loop:
    bge  $t3, $t0, clone_for_loop_end
    sll $t4, $t3, 2 # i * 4
    add $t5, $t1, $t4 # puzzle(ori).grid ith word
    lw   $t6, 0($t5)

    add $t5, $t2, $t4 # puzzle(clone).grid ith word
    sw   $t6, 0($t5)

    addi $t3, $t3, 1 # i++

    j    clone_for_loop
clone_for_loop_end:

    jr  $ra
