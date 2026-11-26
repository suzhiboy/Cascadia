class_name ScoringCardDefinition
extends RefCounted

# Each curve pays once per pattern, with the last increment repeated beyond its table.
const PATTERNS = {
	"crabC":{"shape":"triangle","curve":[2,6,11],"extra":2},
	"limpetD":{"shape":"line","curve":[2,6,11,17],"extra":2},
	"gobyC":{"shape":"shoal","curve":[2,5,8,12],"extra":0},
	"ternC":{"shape":"flight","curve":[2,5,9,14],"extra":0},
	"otterC":{"shape":"pairs","curve":[7,15,24,34],"extra":2}
}

static func pattern_points(rule: Dictionary, size: int) -> int:
	if size == 0: return 0
	var curve = rule.curve
	if size <= curve.size(): return curve[size-1]
	return curve.back()+(size-curve.size())*(curve.back()-curve[-2])

# Each entry stores the title, full rule and sidebar summary.
const DETAILS = {
	"crab": {
		"A": ["掘穴守潮","每只招潮蟹得 2 分。脚下有泥滩就再加 1 分。","泥滩多 1 分"],
		"B": ["开口迎潮","每只招潮蟹先得 1 分。数它脚下地块周围的未铺空位。每两个空位加 1 分，剩一个也加 1 分。","留出空位"],
		"C": ["三角蟹阵","共边的招潮蟹算一群。每群只数一个最好的形状：单只、相邻两只、三只彼此相邻的小三角，分别得 {scores} 分。群里其余每只得 {extra} 分。","三只围成小三角"],
		"D": ["潮线采样","每只招潮蟹得 1 分。挨在一起的招潮蟹算一群。只看群外地块朝向蟹群的那条边，每种地貌加 1 分。同一群里同种地貌只算一次，每只蟹最多给这群带来 2 分加分额度。","认蟹群外的边"]
	},
	"limpet": {
		"A": ["岩面啃藻","每只帽贝先得 1 分。脚下和周围紧挨着的地块里，每块只要有岩礁就加 1 分，最多加 2 分。","找岩礁"],
		"B": ["两岸消浪","每只帽贝先得 2 分。沿穿过它的三条直线看，只要紧挨它、正对的两侧都有地块，就再加 1 分。","两侧正对都有地"],
		"C": ["归壳潮痕","每只帽贝先得 1 分。数脚下地块和邻地相接的边，只有两边地貌相同才算。对上至少一处加 1 分，对上三处或更多再加 1 分。","相接边地貌相同"],
		"D": ["岩脊贝列","共边的帽贝算一群。每群数最长的一条直线，中间不能断。线长 1 至 4 格分别得 {scores} 分，之后每多一格加 {step} 分。线外每只得 {extra} 分，同一群只算一条线。","连成直线"]
	},
	"tern": {
		"A": ["迎风起飞","每只燕鸥先得 1 分。绕着它数连续的未铺空位，看最长的一段。连续两个加 1 分，连续三个或更多加 2 分。","留两个连着的空位"],
		"B": ["展翅分岔","每只燕鸥先得 1 分。沿着它的六条边看，若两个方向各有相邻地块，而且两方向之间刚好隔一条边，就组成一个叉口。每个叉口加 1 分，最多算两个。","向两侧展翅"],
		"C": ["跳岛鸟群","两只燕鸥若在同一直线上，中间恰好隔一块已铺地，就能结伴。沿这些连接找到整群，每只只数一次。每群 1 至 4 只分别得 {scores} 分，之后每多一只加 {step} 分。","隔一格结伴"],
		"D": ["迁徙落脚点","每只燕鸥得 1 分。从燕鸥直着跨过一块地，第二格有砾滩或盐沼就加 1 分。全岛同一落脚格只算一次。全岛有几只燕鸥，最多就数它们两倍的落脚格。","跨地找落脚点"]
	},
	"goby": {
		"A": ["湿泥换气","每只弹涂鱼得 1 分。脚下有泥滩或潮池就加 2 分，即使两种都有也只加一次。","住泥滩或潮池"],
		"B": ["跨滩换位","每只弹涂鱼先得 2 分。只要旁边有一块地与脚下完全没有相同地貌，就再加 1 分。","邻地地貌全不同"],
		"C": ["聚潮鱼群","共边的弹涂鱼组成一群，可以拐弯或分叉。每群单独数，1 至 4 只分别得 {scores} 分，之后每多一只加 {step} 分。","鱼群连成片"],
		"D": ["横穿潮沟","每只弹涂鱼先得 2 分。看穿过它的三条直线，两头紧挨的地块要一边有泥滩、另一边有潮池。第一条符合的线加 2 分，之后每条加 1 分。","泥滩潮池正对"]
	},
	"otter": {
		"A": ["翻石觅食","每只水獭先得 1 分。看紧挨着它的地块，招潮蟹、帽贝、弹涂鱼每看见一种就加 1 分。同种来几只都只加 1 分。","找三种猎物"],
		"B": ["背风育幼湾","每只水獭先得 1 分。绕着它看一圈，如果有三个连着的位置都铺了地块，就加 2 分。只加一次。","三块地围一侧"],
		"C": ["结伴浮游","两只水獭共边，且都没有挨着第三只水獭，就算一对。全岛有 1 至 4 对分别得 {scores} 分，之后每多一对加 {step} 分。没配成对的水獭每只得 {extra} 分。","两两结对"],
		"D": ["水域巡护","每只水獭得 1 分。它脚下或旁边有潮池，就巡护整片。相接边都是潮池才连成一片。每片先加 1 分，再按地块每块加 1 分，最多数三块。几只水獭巡同一片只算一次。","给连片潮池加分"]
	}
}

static func title(animal: String, card: String) -> String:
	return GameLocale.text(DETAILS[animal][card][0])

static func description(animal: String, card: String) -> String:
	var rule = GameLocale.text(DETAILS[animal][card][1])
	var pattern = PATTERNS.get(animal+card)
	if pattern == null: return rule
	var curve = pattern.curve
	return rule.format({"scores":" / ".join(curve),"extra":pattern.extra,"step":curve.back()-curve[-2]})

static func summary(animal: String, card: String) -> String:
	return GameLocale.text(DETAILS[animal][card][2])
