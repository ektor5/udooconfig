UDOO-CONFIG

CLI MODE:

./udoo-config.sh: udoo-config [option] [ARGS...]

UDOO Configuration Tool 

Options:           ARGS:

ch_vncpasswd       PASSWD           Change VNC passwd
ch_passwd          USER, PASSWD     Change user passwd
ch_host            UDOO_NEW         Change hostname
ntpdate_rtc                         Update RTC upon NTP
ch_keyboard        LOCALE           Change keyboard mapping
ch_timezone        ZONE             Change Localzone
expand_fs                           Expand root partition
boot_vram          GPUMEM           Change GPU memory layout
boot_printenv                       Print uboot environment
boot_mmcvars       MMCPART          Change bootargs for mmc boot
boot_satavars      SATAPART         Change bootargs for sata boot
boot_netvars       IPADDR SERVERIP  Change bootargs for network boot
                   NFSROOT GET_CMD  
boot_default       BOOTSRC QUIET    Change boot source
boot_script        SCRIPT           Load script
boot_video         VIDEO_DEV        Change video output [LDB|HDMI]
                   VIDEO_RES
boot_reset                          Reset u-boot environment
startcamera        OPT              Enable camera service
credits                             Shows the credits

