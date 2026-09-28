extends Node

signal rewarded_earned(powerup_type)
signal rewarded_failed(powerup_type)

var _earned_reward := false
var rewarded_ad: RewardedAd = null
var _pending_type: int = -1
var _reward_listener: OnUserEarnedRewardListener = null

const TEST_REWARDED_ID_ANDROID := "ca-app-pub-3088647785863543/7520089873"

var _load_retry_count := 0
const MAX_LOAD_RETRIES := 5

# --- Interstitial Ads ---
var interstitial_ad: InterstitialAd = null
const TEST_INTERSTITIAL_ID_ANDROID := "ca-app-pub-3088647785863543/5266505207"

var _interstitial_load_retry_count := 0

var _restart_press_count := 0
var _restarts_since_last_interstitial := 0
const MIN_RESTARTS_BETWEEN_INTERSTITIALS := 2
const INTERSTITIAL_CHANCE := 0.2

var _last_interstitial_unix_time := 0
const MIN_SECONDS_BETWEEN_INTERSTITIALS := 60


func _load_interstitial_ad():
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad):
		print("AdsManager: interstitial LOADED successfully")
		_interstitial_load_retry_count = 0
		interstitial_ad = ad
	callback.on_ad_failed_to_load = func(error):
		print("AdsManager: interstitial FAILED to load — ", error)
		interstitial_ad = null
		_interstitial_load_retry_count += 1
		if _interstitial_load_retry_count <= MAX_LOAD_RETRIES:
			var delay = 2.0 * _interstitial_load_retry_count
			print("AdsManager: retrying interstitial load in ", delay, "s")
			await get_tree().create_timer(delay).timeout
			_load_interstitial_ad()
		else:
			print("AdsManager: giving up on interstitial after ", MAX_LOAD_RETRIES, " attempts")
	var request := AdRequest.new()
	InterstitialAdLoader.new().load(TEST_INTERSTITIAL_ID_ANDROID, request, callback)


func is_interstitial_ready() -> bool:
	return interstitial_ad != null


# Call this from the restart button handler. It always calls on_ready_to_restart
# exactly once — either immediately (no ad shown) or after the interstitial
# is dismissed (ad shown). Never blocks longer than that.
func request_interstitial_on_restart(on_ready_to_restart: Callable):
	_restart_press_count += 1
	_restarts_since_last_interstitial += 1

	var eligible := _restart_press_count > 1 \
		and _restarts_since_last_interstitial > MIN_RESTARTS_BETWEEN_INTERSTITIALS \
		and (Time.get_unix_time_from_system() - _last_interstitial_unix_time) >= MIN_SECONDS_BETWEEN_INTERSTITIALS

	var should_show := eligible and randf() < INTERSTITIAL_CHANCE and is_interstitial_ready()

	if not should_show:
		on_ready_to_restart.call()
		return

	print("AdsManager: showing interstitial on restart")
	_restarts_since_last_interstitial = 0
	_last_interstitial_unix_time = Time.get_unix_time_from_system()

	var fullscreen_callback := FullScreenContentCallback.new()
	fullscreen_callback.on_ad_dismissed_full_screen_content = func():
		print("AdsManager: interstitial dismissed")
		interstitial_ad = null
		_load_interstitial_ad()
		on_ready_to_restart.call()
	fullscreen_callback.on_ad_failed_to_show_full_screen_content = func(error):
		print("AdsManager: interstitial failed to show — ", error)
		interstitial_ad = null
		_load_interstitial_ad()
		on_ready_to_restart.call()
	fullscreen_callback.on_ad_showed_full_screen_content = func():
		print("AdsManager: interstitial shown")
	fullscreen_callback.on_ad_impression = func():
		print("AdsManager: interstitial impression recorded")

	interstitial_ad.full_screen_content_callback = fullscreen_callback
	interstitial_ad.show()
	
func _ready():
	print("AdsManager: waiting for consent flow to resolve...")
	if ConsentManager._resolved:
		_start_ads()
	else:
		ConsentManager.consent_ready.connect(_start_ads, CONNECT_ONE_SHOT)

func _start_ads():
	print("AdsManager: initializing MobileAds...")
	MobileAds.initialize()
	await get_tree().create_timer(2.0).timeout
	print("AdsManager: attempting first rewarded ad load")
	_load_rewarded_ad()
	print("AdsManager: attempting first interstitial load")
	_load_interstitial_ad()

func _load_rewarded_ad():
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad):
		print("AdsManager: rewarded ad LOADED successfully")
		_load_retry_count = 0
		rewarded_ad = ad
	callback.on_ad_failed_to_load = func(error):
		print("AdsManager: rewarded ad FAILED to load — ", error)
		rewarded_ad = null
		_load_retry_count += 1
		if _load_retry_count <= MAX_LOAD_RETRIES:
			var delay = 2.0 * _load_retry_count  # backoff: 2s, 4s, 6s...
			print("AdsManager: retrying load in ", delay, "s (attempt ", _load_retry_count, ")")
			await get_tree().create_timer(delay).timeout
			_load_rewarded_ad()
		else:
			print("AdsManager: giving up after ", MAX_LOAD_RETRIES, " failed attempts")
	var request := AdRequest.new()
	RewardedAdLoader.new().load(TEST_REWARDED_ID_ANDROID, request, callback)
	
func is_rewarded_ready() -> bool:
	return rewarded_ad != null

func show_rewarded_ad(powerup_type: int):
	if not rewarded_ad:
		print("AdsManager: show requested but rewarded_ad is null (not loaded)")
		rewarded_failed.emit(powerup_type)
		return

	_pending_type = powerup_type
	_earned_reward = false

	# Reward callback
	_reward_listener = OnUserEarnedRewardListener.new()
	_reward_listener.on_user_earned_reward = func(_reward_item):
		print("Reward earned")
		_earned_reward = true
		
	get_tree().paused = true
	
	# Fullscreen callbacks
	var fullscreen_callback := FullScreenContentCallback.new()

	fullscreen_callback.on_ad_dismissed_full_screen_content = func():
		print("Ad dismissed")
		get_tree().paused = false
		# Only grant the reward AFTER the ad has completely closed.
		if _earned_reward:
			rewarded_earned.emit(_pending_type)

		rewarded_ad = null
		_load_rewarded_ad()

	fullscreen_callback.on_ad_failed_to_show_full_screen_content = func(error):
		print("Failed to show rewarded ad: ", error)
		get_tree().paused = false
		rewarded_failed.emit(_pending_type)

	fullscreen_callback.on_ad_showed_full_screen_content = func():
		print("Rewarded ad shown")

	fullscreen_callback.on_ad_clicked = func():
		print("Rewarded ad clicked")

	fullscreen_callback.on_ad_impression = func():
		print("Rewarded ad impression recorded")

	rewarded_ad.full_screen_content_callback = fullscreen_callback

	# Show the ad
	rewarded_ad.show(_reward_listener)
	
	
