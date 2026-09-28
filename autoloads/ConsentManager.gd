extends Node
## Autoload singleton. Register as "ConsentManager" in
## Project Settings -> Autoload, pointing at this script.
##
## Handles the GDPR/UMP consent flow required before showing ads to
## EEA/UK users. Emits `consent_ready` exactly once, when it's safe to
## call MobileAds.initialize() and start loading ads — whether or not
## consent was actually required for this user.

signal consent_ready

const IS_DEBUG_TESTING := false  # TEMP: set true only while testing with a real test device hashed ID below
const TEST_DEVICE_HASHED_ID := ""  # fill in your device's hashed ID if IS_DEBUG_TESTING is true

var _consent_info: ConsentInformation
var _resolved := false

func _ready():
	_consent_info = UserMessagingPlatform.consent_information

	var params := ConsentRequestParameters.new()
	params.tag_for_under_age_of_consent = false

	if IS_DEBUG_TESTING:
		var debug_settings := ConsentDebugSettings.new()
		# NOTE: set debug_settings.debug_geography to force the EEA testing
		# geography if needed — check the DebugGeography enum (same addons/admob
		# folder) for the exact constant name (likely DebugGeography.Values.EEA).
		# Left at its default here since that file wasn't available to confirm.
		if TEST_DEVICE_HASHED_ID != "":
			debug_settings.test_device_hashed_ids = [TEST_DEVICE_HASHED_ID]
		params.consent_debug_settings = debug_settings

	print("ConsentManager: requesting consent info update...")
	_consent_info.update(
		params,
		_on_consent_info_updated_success,
		_on_consent_info_updated_failure
	)

func _on_consent_info_updated_success() -> void:
	print("ConsentManager: consent info updated, status = ", _consent_info.get_consent_status())

	var status = _consent_info.get_consent_status()

	if status == ConsentInformation.ConsentStatus.REQUIRED and _consent_info.get_is_consent_form_available():
		print("ConsentManager: consent form required, loading it...")
		UserMessagingPlatform.load_consent_form(
			_on_consent_form_load_success,
			_on_consent_form_load_failure
		)
	else:
		# Not required, already obtained, or not available — safe to proceed.
		_finish()

func _on_consent_info_updated_failure(form_error: FormError) -> void:
	print("ConsentManager: consent info update FAILED — ", form_error)
	# Fail open: don't block the game from starting if consent info can't be
	# fetched (e.g. no network on first launch). Ads will still respect
	# whatever default/non-personalized behavior the SDK falls back to.
	_finish()

func _on_consent_form_load_success(consent_form: ConsentForm) -> void:
	print("ConsentManager: consent form loaded, showing it...")
	consent_form.show(_on_consent_form_dismissed)

func _on_consent_form_load_failure(form_error: FormError) -> void:
	print("ConsentManager: consent form FAILED to load — ", form_error)
	_finish()

func _on_consent_form_dismissed(form_error: FormError) -> void:
	if form_error:
		print("ConsentManager: consent form dismissed with error — ", form_error)
	else:
		print("ConsentManager: consent form dismissed, status now = ", _consent_info.get_consent_status())

	# After the form is dismissed, status may still be REQUIRED if the user
	# dismissed without choosing (e.g. backed out). Re-check once; if still
	# required and a form is still available, this would loop forever if we
	# kept re-showing it — so we only ever show it once per app session here.
	_finish()

func _finish() -> void:
	if _resolved:
		return
	_resolved = true
	print("ConsentManager: consent flow resolved, ready to init ads")
	consent_ready.emit()
