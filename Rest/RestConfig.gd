extends Resource
class_name RestConfig

@export var merchant_card_offer_count: int = 3
@export var merchant_relic_offer_count: int = 2

@export_group("Merchant Card Prices")
@export var merchant_card_price_common: int = 65
@export var merchant_card_price_uncommon: int = 105
@export var merchant_card_price_rare: int = 155
@export var merchant_card_price_legendary: int = 230

@export_group("Merchant Relic Prices")
@export var merchant_relic_price_common: int = 145
@export var merchant_relic_price_uncommon: int = 210
@export var merchant_relic_price_rare: int = 300
@export var merchant_relic_price_legendary: int = 420

@export_group("Smith")
@export var smith_upgrade_price: int = 90
