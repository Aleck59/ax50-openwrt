# Дополнение /etc/diag.sh таргета Intel (подключается в его конце): там нет
# состояния upgrade, и при sysupgrade светодиод питания не мигал. Функция
# set_state переопределяется целиком — состояния таргета без изменений, плюс
# upgrade (алиас led-upgrade в DTS AX50 указывает на blue:power).

upgrade="$(lantiq_get_dt_led upgrade)"

set_state() {
	status_led="$boot"

	case "$1" in
	preinit)
		status_led_blink_preinit
		;;
	failsafe)
		status_led_off
		[ -n "$running" ] && {
			status_led="$running"
			status_led_off
		}
		status_led="$failsafe"
		status_led_blink_failsafe
		;;
	preinit_regular)
		status_led_blink_preinit_regular
		;;
	upgrade)
		status_led="${upgrade:-$boot}"
		status_led_blink_preinit_regular
		;;
	done)
		status_led_off
		[ -n "$running" ] && {
			status_led="$running"
			status_led_on
		}
		;;
	esac
}
