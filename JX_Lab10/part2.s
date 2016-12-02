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

	li	$t4, ON_FIRE_MASK	# on fire interrupt enable bit
	or	$t4, $t4, 1		# global interrupt enable
	mtc0	$t4, $12		# set interrupt mask (Status register)

	li 	$t0,	0
	sw 	$t0,	VELOCITY
infinite:
	j	infinite

	# note that we infinite loop to avoid stopping the simulation early
	j	main


.kdata				# interrupt handler data (separated just for readability)
chunkIH:	.space 44	# space for 10 registers
non_intrpt_str:	.asciiz "Non-interrupt exception\n"
unhandled_str:	.asciiz "Unhandled interrupt type\n"

.ktext 0x80000180
interrupt_handler:
.set noat
	move	$k1, $at		# Save $at                               
.set at
	la	$k0, chunkIH
	sw	$a0, 0($k0)		# Get some free registers                  
	sw	$a1, 4($k0)		# by storing them to a global variable
	sw 	$t0,	8($k0)     
	sw 	$t1,	12($k0)
	sw 	$t2,	16($k0)
	sw 	$t3,	20($k0)
	sw 	$t4,	24($k0)
	sw 	$t5,	28($k0)
	sw 	$t6,	32($k0)
	sw 	$t7,	36($k0)
	sw 	$v0,	40($k0)

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


	# add dispatch for other interrupt types here.

	li	$v0, PRINT_STRING	# Unhandled interrupt types
	la	$a0, unhandled_str
	syscall 
	j	done

on_fire_interrupt:
	sw	$a1,	ON_FIRE_ACK		# acknowledge interrupt

	lw 	$a1,	GET_FIRE_LOC
	srl 	$t0,	$a1,	16		# $t0 = fire location x index 
	and 	$t1,	$a1,	0x0000ffff	# $t1 = fire location y index 
	li 	$t7,	30
	mul 	$t0,	$t0,	$t7
	add 	$t0,	$t0,	15	# $t0 = 15 + x * 30
	mul 	$t1,	$t1,	$t7
	add 	$t1,	$t1,	15	# $t1 = 15 + y * 30
	lw 	$t2,	BOT_X 
	lw 	$t3,	BOT_Y

	# Put out fire!
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
	sw 	$t7 	PUT_OUT_FIRE
	sw 	$zero	VELOCITY

	j	interrupt_dispatch	# see if other interrupts are waiting




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
	lw 	$v0,	40($k0)
.set noat
	move	$at, $k1		# Restore $at
.set at 
	eret   
