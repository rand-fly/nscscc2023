BTB_LOG = True


btb_valid = [False]*32
btb_tag = [0]*32
btb_target = [0]*32
btb_ins_type = [0]*32
btb_replace_counter = [False]*16

btb_target_pc_0 = 0
btb_target_pc_1 = 0
btb_ins_type_0 = 0
btb_ins_type_1 = 0
def btb_fetch(pc_0, pc_1):
	"""读取行为"""
	global btb_target_pc_0
	global btb_target_pc_1
	global btb_ins_type_0
	global btb_ins_type_1

	btb_target_pc_0 = 0
	btb_target_pc_1 = 0
	btb_ins_type_0 = 0
	btb_ins_type_1 = 0
	pc_0 = pc_0>>2
	pc_1 = pc_1>>2
	group_0 = pc_0 % 16
	group_1 = pc_1 % 16
	tag_0 = ((pc_0 & 0x3f)>>0)^((pc_0 & 0xfc0)>>6)^((pc_0 & 0x3f000)>>12)^((pc_0 & 0xfc0000)>>18)^((pc_0 & 0x3f000000)>>24)
	tag_1 = ((pc_1 & 0x3f)>>0)^((pc_1 & 0xfc0)>>6)^((pc_1 & 0x3f000)>>12)^((pc_1 & 0xfc0000)>>18)^((pc_1 & 0x3f000000)>>24)
	#print(hex(tag_0),hex(tag_1))
	fi_0 = -1
	fi_1 = -1
	
	for i in range(0,2):
		i_0 = group_0*2 + i
		i_1 = group_1*2 + i
		if(btb_valid[i_0] and tag_0 == btb_tag[i_0]):
			btb_target_pc_0 = btb_target[i_0]
			btb_ins_type_0 = btb_ins_type[i_0]
			fi_0 = i
		if(btb_valid[i_1] and tag_1 == btb_tag[i_1]):
			btb_target_pc_1 = btb_target[i_1]
			btb_ins_type_1 = btb_ins_type[i_1]
			fi_1 = i
	if(BTB_LOG):
		print("Log:Find", hex(pc_0*4), ",", hex(pc_1*4), " In BTB")
		print("\tGot result:{", hex(btb_target_pc_0), ",", hex(btb_target_pc_1),"}")
		print("\tIns type:{", bin(btb_ins_type_0), ",", bin(btb_ins_type_1), "}")
		print("\tIn BTB index:{", hex(group_0*2 + fi_0), ",", hex(group_1*2 + fi_1),"}\n")


def btb_update(ins_type_w, wrong_pc, right_target):
	"""修正行为"""
	if(BTB_LOG):
		print("Log:Update PC:", hex(wrong_pc), " In BTB")
		print("\twith Ins Type:", bin(ins_type_w), ",Right Target: ", hex(right_target))
	wrong_pc = wrong_pc>>2
	group_w = wrong_pc % 16
	tag_w = ((wrong_pc & 0x3f)>>0)^((wrong_pc & 0xfc0)>>6)^((wrong_pc & 0x3f000)>>12)^((wrong_pc & 0xfc0000)>>18)^((wrong_pc & 0x3f000000)>>24)
	
	#替换同tag
	for i in range(0,2):
		i_w = group_w*2 + i
		if(btb_valid[i_w] and tag_w == btb_tag[i_w]):
			btb_target[i_w] = right_target
			btb_ins_type[i_w] = ins_type_w
			btb_replace_counter[group_w] = not btb_replace_counter[group_w]
			if(BTB_LOG):
				print("\tReplaced", hex(i_w), "with SAME_TAG\n")
			return
	#填补空行
	inv_hit = False;
	inv_i = 0;
	for i in range(0,2):
		i_w = group_w*2 + i
		if(not btb_valid[i_w]):
			inv_hit = True
			inv_i = i_w
	if(inv_hit):
		btb_tag[inv_i] = tag_w
		btb_target[inv_i] = right_target
		btb_ins_type[inv_i] = ins_type_w
		btb_valid[inv_i] = True
		btb_replace_counter[group_w] = not btb_replace_counter[group_w]
		if(BTB_LOG):
			print("\tReplaced", hex(inv_i), "with EMPTY_LINE\n")
		return
	#轮流替换
	i_w = group_w*2 + int(btb_replace_counter[group_w])
	btb_tag[i_w] = tag_w
	btb_target[i_w] = right_target
	btb_ins_type[i_w] = ins_type_w
	btb_valid[i_w] = True
	btb_replace_counter[group_w] = not btb_replace_counter[group_w]
	if(BTB_LOG):
		print("\tReplaced", hex(i_w), "with COUNTER_REPLACE\n")
	return

def btb_reset():
	"""重置行为"""
	btb_valid = [False]*32
	btb_replace_counter = [False]*16



bht = [0]*64
hashed_index_0 = 0
hashed_index_1 = 0
hashed_index_o = 0
hashed_index_w = 0

def bht_fetch(pc_0, pc_1, retire_pc, wrong_pc):
	"""查bht，在更新各部件、查询各部件之前都要查"""

	global hashed_index_0
	global hashed_index_1
	global hashed_index_o
	global hashed_index_w

	bht_index_0 = ((pc_0>>2) & 0x3f)^((pc_0>>8) & 0x3f)^((pc_0>>14) & 0x3f)^((pc_0>>20) & 0x3f)^((pc_0>>26) & 0x3f)
	bht_index_1 = ((pc_1>>2) & 0x3f)^((pc_1>>8) & 0x3f)^((pc_1>>14) & 0x3f)^((pc_1>>20) & 0x3f)^((pc_1>>26) & 0x3f)
	bht_index_o = ((retire_pc>>2) & 0x3f)^((retire_pc>>8) & 0x3f)^((retire_pc>>14) & 0x3f)^((retire_pc>>20) & 0x3f)^((retire_pc>>26) & 0x3f)
	bht_index_w = ((wrong_pc>>2) & 0x3f)^((wrong_pc>>8) & 0x3f)^((wrong_pc>>14) & 0x3f)^((wrong_pc>>20) & 0x3f)^((wrong_pc>>26) & 0x3f)

	bht_val_0 = bht[bht_index_0]
	bht_val_1 = bht[bht_index_1]
	bht_val_o = bht[bht_index_o]
	bht_val_w = bht[bht_index_w]

	#print(hex((retire_pc>>2) & 0xff))

	hashed_index_0 = ((pc_0>>2) & 0xff) ^ bht_val_0
	hashed_index_1 = ((pc_1>>2) & 0xff) ^ bht_val_1
	hashed_index_o = ((retire_pc>>2) & 0xff) ^ bht_val_o
	hashed_index_w = ((wrong_pc>>2) & 0xff) ^ bht_val_w

def bht_update(retire_pc,right_orien):
	"""更新bht"""
	bht_index_o = ((retire_pc>>2) & 0x3f)^((retire_pc>>8) & 0x3f)^((retire_pc>>14) & 0x3f)^((retire_pc>>20) & 0x3f)^((retire_pc>>26) & 0x3f)
	bht[bht_index_o] = ((bht[bht_index_o] << 1) & 0xff) + int(right_orien)

def bht_reset():
	"""重置"""
	global bht
	bht = [0]*64

pht = [0]*256
taken_0 = False
taken_1 = False
def pht_fetch():
	"""在取bht后进行方向预测"""
	global taken_0
	global taken_1
	taken_0 = pht[hashed_index_0] >= 2
	taken_1 = pht[hashed_index_1] >= 2

def pht_update(right_orien):
	if(right_orien):
		if(pht[hashed_index_o] < 3):
			pht[hashed_index_o] += 1
	else:
		if(pht[hashed_index_o] > 0):
			pht[hashed_index_o] -= 1


bht_update(0x12345678, True)
bht_fetch(0x12345678, 0x22345678,0x12345678, 0x22345678)
pht_update(True)
print(hashed_index_o)
bht_update(0x12345678, True)
bht_fetch(0x12345678, 0x22345678,0x12345678, 0x22345678)
pht_update(True)
print(hashed_index_o)
bht_update(0x12345678, True)
bht_fetch(0x12345678, 0x22345678,0x12345678, 0x22345678)
pht_update(True)
print(hashed_index_o)
bht_update(0x12345678, True)
bht_fetch(0x12345678, 0x22345678,0x12345678, 0x22345678)
pht_update(True)
print(hashed_index_o)
bht_update(0x12345678, True)
bht_fetch(0x12345678, 0x22345678,0x12345678, 0x22345678)
pht_update(True)
print(hashed_index_o)
bht_update(0x12345678, True)
bht_fetch(0x12345678, 0x22345678,0x12345678, 0x22345678)
pht_update(True)
print(hashed_index_o)
bht_update(0x12345678, True)
bht_fetch(0x12345678, 0x22345678,0x12345678, 0x22345678)
pht_update(True)
print(hashed_index_o)
bht_update(0x12345678, True)
bht_fetch(0x12345678, 0x22345678,0x12345678, 0x22345678)
pht_update(True)
print(hashed_index_o)
bht_update(0x12345678, True)
bht_fetch(0x12345678, 0x22345678,0x12345678, 0x22345678)
pht_update(True)
print(hashed_index_o)
bht_update(0x12345678, True)
bht_fetch(0x12345678, 0x22345678,0x12345678, 0x22345678)
pht_update(True)
print(hashed_index_o)
bht_update(0x12345678, True)
bht_fetch(0x12345678, 0x22345678,0x12345678, 0x22345678)
pht_update(True)
print(hashed_index_o)
bht_update(0x12345678, True)
bht_fetch(0x12345678, 0x22345678,0x12345678, 0x22345678)
pht_update(True)
bht_update(0x12345678, True)
bht_fetch(0x12345678, 0x22345678,0x12345678, 0x22345678)
pht_update(True)
bht_update(0x12345678, True)
bht_fetch(0x12345678, 0x22345678,0x12345678, 0x22345678)
pht_update(True)
print(pht)