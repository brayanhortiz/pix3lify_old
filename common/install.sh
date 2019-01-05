patch_xml() {
  local VAR1 VAR2 NAME NAMEC VALC VAL
  NAME=$(echo "$3" | sed -r "s|^.*/.*\[@.*=\"(.*)\".*$|\1|")
  NAMEC=$(echo "$3" | sed -r "s|^.*/.*\[@(.*)=\".*\".*$|\1|")
  if [ "$(echo $4 | grep '=')" ]; then
    VALC=$(echo "$4" | sed -r "s|(.*)=.*|\1|"); VAL=$(echo "$4" | sed -r "s|.*=(.*)|\1|")
  else
    VALC="value"; VAL="$4"
  fi
  case $2 in
    *dialer_phenotype_flags*.xml)  sed -i "/#DIALERPATCHES/a\          patch_xml $1 \$MODPATH/\ '$3' \"$4\"" $INSTALLER/common/ppost-fs-data.sh; VAR1=boolean; VAR2=string; VAR3=long;;
    *mixer_paths*.xml) sed -i "/#MIXERPATCHES/a\                       patch_xml $1 \$MODPATH/\$NAME '$3' \"$4\"" $INSTALLER/common/aml.sh; VAR1=ctl; VAR2=mixer;;
    *sapa_feature*.xml) sed -i "/#SAPAPATCHES/a\                        patch_xml $1 \$MODPATH/\$NAME '$3' \"$4\"" $INSTALLER/common/aml.sh; VAR1=feature; VAR2=model;;
    *mixer_gains*.xml) sed -i "/#GAINPATCHES/a\                       patch_xml $1 \$MODPATH/\$NAME '$3' \"$4\"" $INSTALLER/common/aml.sh; VAR1=ctl; VAR2=mixer;;
    *audio_device*.xml) sed -i "/#ADPATCHES/a\                        patch_xml $1 \$MODPATH/\$NAME '$3' \"$4\"" $INSTALLER/common/aml.sh; VAR1=kctl; VAR2=mixercontrol;;
    *audio_platform_info*.xml) sed -i "/#APLIPATCHES/a\                               patch_xml $1 \$MODPATH/\$NAME '$3' \"$4\"" $INSTALLER/common/aml.sh; VAR1=param; VAR2=config_params;;
  esac
  if [ "$1" == "-t" -o "$1" == "-ut" -o "$1" == "-tu" ] && [ "$VAR1" ]; then
    if [ "$(grep "<$VAR1 $NAMEC=\"$NAME\" $VALC=\".*\" />" $2)" ]; then
      sed -i "0,/<$VAR1 $NAMEC=\"$NAME\" $VALC=\".*\" \/>/ {/<$VAR1 $NAMEC=\"$NAME\" $VALC=\".*\" \/>/p; s/\(<$VAR1 $NAMEC=\"$NAME\" $VALC=\".*\" \/>\)/<!--$MODID\1$MODID-->/}" $2
      sed -i "0,/<$VAR1 $NAMEC=\"$NAME\" $VALC=\".*\" \/>/ s/\(<$VAR1 $NAMEC=\"$NAME\" $VALC=\"\).*\(\" \/>\)/\1$VAL\2<!--$MODID-->/" $2
    elif [ "$1" == "-t" ]; then
      sed -i "/<$VAR2>/ a\    <$VAR1 $NAMEC=\"$NAME\" $VALC=\"$VAL\" \/><!--$MODID-->" $2
    fi    
  elif [ "$(xmlstarlet sel -t -m "$3" -c . $2)" ]; then
    [ "$(xmlstarlet sel -t -m "$3" -c . $2 | sed -r "s/.*$VALC=(\".*\").*/\1/")" == "$VAL" ] && return
    xmlstarlet ed -P -L -i "$3" -t elem -n "$MODID" $2
    sed -ri "s/(^ *)(<$MODID\/>)/\1\2\n\1/g" $2
    local LN=$(sed -n "/<$MODID\/>/=" $2)
    for i in ${LN}; do
      sed -i "$i d" $2
      case $(sed -n "$((i-1)) p" $2) in
        *">$MODID-->") sed -i -e "${i-1}s/<!--$MODID-->//" -e "${i-1}s/$/<!--$MODID-->/" $2;;
        *) sed -i "$i p" $2
           sed -ri "${i}s/(^ *)(.*)/\1<!--$MODID\2$MODID-->/" $2
           sed -i "$((i+1))s/$/<!--$MODID-->/" $2;;
      esac
    done
    case "$1" in
      "-u"|"-s") xmlstarlet ed -L -u "$3/@$VALC" -v "$VAL" $2;;
      "-d") xmlstarlet ed -L -d "$3" $2;;
    esac
  elif [ "$1" == "-s" ]; then
    local NP=$(echo "$3" | sed -r "s|(^.*)/.*$|\1|")
    local SNP=$(echo "$3" | sed -r "s|(^.*)\[.*$|\1|")
    local SN=$(echo "$3" | sed -r "s|^.*/.*/(.*)\[.*$|\1|")
    xmlstarlet ed -L -s "$NP" -t elem -n "$SN-$MODID" -i "$SNP-$MODID" -t attr -n "$NAMEC" -v "$NAME" -i "$SNP-$MODID" -t attr -n "$VALC" -v "$VAL" $2
    xmlstarlet ed -L -r "$SNP-$MODID" -v "$SN" $2
    xmlstarlet ed -L -i "$3" -t elem -n "$MODID" $2
    local LN=$(sed -n "/<$MODID\/>/=" $2)
    for i in ${LN}; do
      sed -i "$i d" $2
      sed -ri "${i}s/$/<!--$MODID-->/" $2
    done 
  fi
  local LN=$(sed -n "/^ *<!--$MODID-->$/=" $2 | tac)
  for i in ${LN}; do
    sed -i "$i d" $2
    sed -ri "$((i-1))s/$/<!--$MODID-->/" $2
  done 
}

keytest() {
  ui_print " - Vol Key Test -"
  ui_print "   Press Vol Up:"
  (/system/bin/getevent -lc 1 2>&1 | /system/bin/grep VOLUME | /system/bin/grep " DOWN" > $INSTALLER/events) || return 1
  return 0
}

choose() {
  # Note from chainfire @xda-developers: getevent behaves weird when piped, and busybox grep likes that even less than toolbox/toybox grep
  while true; do
    /system/bin/getevent -lc 1 2>&1 | /system/bin/grep VOLUME | /system/bin/grep " DOWN" > $INSTALLER/events
    if (`cat $INSTALLER/events 2>/dev/null | /system/bin/grep VOLUME >/dev/null`); then
      break
    fi
  done
  if (`cat $INSTALLER/events 2>/dev/null | /system/bin/grep VOLUMEUP >/dev/null`); then
    return 0
  else
    return 1
  fi
}

chooseold() {
  # Calling it first time detects previous input. Calling it second time will do what we want
  keycheck
  keycheck
  SEL=$?
  if [ "$1" == "UP" ]; then
    UP=$SEL
  elif [ "$1" == "DOWN" ]; then
    DOWN=$SEL
  elif [ $SEL -eq $UP ]; then
    return 0
  elif [ $SEL -eq $DOWN ]; then
    return 1
  else
    ui_print "   Vol key not detected!"
    abort "   Use name change method in TWRP"
  fi
}

SLIM=false; FULL=false; OVER=false; BOOT=false; ACC=false;
# Gets stock/limit from zip name
case $(basename $ZIP) in
  *slim*|*Slim*|*SLIM*) SLIM=true;;
  *full*|*Full*|*FULL*) FULL=true;;
  *over*|*Over*|*OVER*) OVER=true;;
  *boot*|*Boot*|*BOOT*) BOOT=true;;
  *acc*|*Acc*|*ACC*) ACC=true;;
esac


if [ "$PX1" ] || [ "$PX1XL" ] || [ "$PX2" ] || [ "$PX2XL" ] || [ "$PX3" ] || [ "$PX3XL" ] || [ "$N5X" ] || [ "$N6P" ] || [ "$OOS" ]; then
  ui_print " "
  if [ "$OOS" ]; then
    ui_print "   Pix3lify has been known to not work and cause issues on devices running OxygenOS!"
  else
    ui_print "   Pix3lify is only for non-Google devices!"
  fi
  ui_print "   DO YOU WANT TO IGNORE OUR WARNINGS AND RISK A BOOTLOOP?"
  ui_print "   Vol Up = Yes, Vol Down = No"
  if $FUNCTION; then
    ui_print " "
    ui_print "   Ignoring warnings..."
  else
    ui_print " "
    ui_print "   Exiting..."
    abort
  fi
fi

ui_print " "
ui_print "   Removing remnants from past Pix3lify installs..."
# Removes /data/resource-cache/overlays.list
OVERLAY='/data/resource-cache/overlays.list'
if [ -f "$OVERLAY" ]; then
  ui_print "   Removing $OVERLAY"
  rm -f "$OVERLAY"
fi

if [ "$SLIM" == false -a "$FULL" == false -a "$OVER" == false -a "$BOOT" ]; then
  if keytest; then
    FUNCTION=choose
  else
    FUNCTION=chooseold
    ui_print "   ! Legacy device detected! Using old keycheck method"
    ui_print " "
    ui_print " - Vol Key Programming -"
    ui_print "   Press Vol Up:"
    $FUNCTION "UP"
    ui_print "   Press Vol Down:"
    $FUNCTION "DOWN"
  fi

  if ! $SLIM && ! $FULL && ! $OVER && ! $BOOT && ! $ACC; then
    ui_print " "
    ui_print " - Slim Options -"
    ui_print "   Do you want to enable slim mode (heavily reduced featureset, see README)?"
    ui_print "   Vol Up = Yes, Vol Down = No"
    if $FUNCTION; then
      SLIM=true
    else
      FULL=true
    fi
    if $FULL; then
      ui_print " "
      ui_print " - Overlay Options -"
      ui_print "   Do you want the Pixel overlays enabled?"
      ui_print "   Vol Up = Yes, Vol Down = No"
      if $FUNCTION; then
        OVER=true
        ui_print " "
        ui_print " - Accent Options -"
        ui_print "   Do you want the Pixel accent enabled?"
        ui_print "   Vol Up = Yes, Vol Down = No"
        if $FUNCTION; then
          ACC=true
        fi
      fi
    fi
    ui_print " "
    ui_print " - Animation Options -"
    ui_print "   Do you want the Pixel boot animation?"
    ui_print "   Vol Up = Yes, Vol Down = No"
    if $FUNCTION; then
      BOOT=true
    fi
  else
    ui_print " Options specified in zip name!"
  fi
fi

# had to break up volume options this way for basename zip for users without working vol keys
if $SLIM; then
  ui_print " "
  ui_print "   Enabling slim mode..."
  rm -rf $INSTALLER/system/app
  rm -rf $INSTALLER/system/fonts
  rm -rf $INSTALLER/system/lib
  rm -rf $INSTALLER/system/lib64
  rm -rf $INSTALLER/system/media
  rm -rf $INSTALLER/system/priv-app
  rm -rf $INSTALLER/system/vendor/overlay/DisplayCutoutEmulationCorner
  rm -rf $INSTALLER/system/vendor/overlay/DisplayCutoutEmulationDouble
  rm -rf $INSTALLER/system/vendor/overlay/DisplayCutoutEmulationTall
  rm -rf $INSTALLER/system/vendor/overlay/DisplayCutoutNoCutout
  rm -rf $INSTALLER/system/vendor/overlay/Pixel
  rm -rf /data/resource-cache
fi

if $FULL; then
  ui_print " "
  ui_print " Full mode selected..."
  prop_process $INSTALLER/common/full.prop
  if $OVER; then
    ui_print " "
    ui_print "   Enabling overlay features..."
  else
    ui_print " "
    ui_print "   Disabling overlay features..."
    rm -f $INSTALLER/system/vendor/overlay/Pix3lify.apk
    rm -rf /data/resource-cache
    rm -rf /data/dalvik-cache
    ui_print "   Dalvik-Cache has been cleared!"
    ui_print "   Next boot may take a little longer to boot!"
  fi
  if $ACC; then
    ui_print " "
    ui_print "   Enabling Pixel accent..."
  else
    ui_print " "
    ui_print "   Disabling Pixel accent..."
       sed -i 's/ro.boot.vendor.overlay.theme/# ro.boot.vendor.overlay.theme/g' $INSTALLER/common/system.prop
    rm -rf $INSTALLER/system/vendor/overlay/Pixel
    rm -rf /data/resource-cache
  fi
fi

if $BOOT; then
  ui_print " "
  ui_print "   Enabling boot animation..."
  cp -f $INSTALLER/common/bootanimation.zip $UNITY$BFOLDER$BZIP
else
  ui_print " "
  ui_print "   Disabling boot animation..."
fi

if [ $API -ge 27 ]; then
  rm -rf $INSTALLER/system/framework
fi

if [ $API -ge 28 ]; then
  ui_print " "
  ui_print "   Enabling Google's Call Screening..."
  DPF=/data/data/com.google.android.dialer/shared_prefs/dialer_phenotype_flags.xml
  if [ -f $DPF ]; then
    # Enabling Google's Call Screening
    patch_xml -s $DPF '/map/boolean[@name="G__speak_easy_bypass_locale_check"]' "true"
    patch_xml -s $DPF '/map/boolean[@name="G__speak_easy_enable_listen_in_button"]' "true"
    patch_xml -s $DPF '/map/boolean[@name="__data_rollout__SpeakEasy.OverrideUSLocaleCheckRollout__launched__"]' "true"
    patch_xml -s $DPF '/map/boolean[@name="G__enable_speakeasy_details"]' "true"
    patch_xml -s $DPF '/map/boolean[@name="G__speak_easy_enabled"]' "true"
    patch_xml -s $DPF '/map/boolean[@name="G__speakeasy_show_privacy_tour"]' "true"
    patch_xml -s $DPF '/map/boolean[@name="__data_rollout__SpeakEasy.SpeakEasyDetailsRollout__launched__"]' "true"
    patch_xml -s $DPF '/map/boolean[@name="__data_rollout__SpeakEasy.CallScreenOnPixelTwoRollout__launched__"]' "true"
    patch_xml -s $DPF '/map/boolean[@name="G__speakeasy_postcall_survey_enabled"]' "true"
  fi
fi
  if [ "$SLIM" == "false" ]; then
    ui_print " "
    ui_print "   Enabling Google's Flip to Shhh..."
    ui_print " "
    # Enabling Google's Flip to Shhh
    WELLBEING_PREF_FILE=$INSTALLER/common/PhenotypePrefs.xml
    chmod 660 $WELLBEING_PREF_FILE
    WELLBEING_PREF_FOLDER=/data/data/com.google.android.apps.wellbeing/shared_prefs/
    mkdir -p $WELLBEING_PREF_FOLDER
    cp -p $WELLBEING_PREF_FILE $WELLBEING_PREF_FOLDER
    if $MAGISK && $BOOTMODE; then
      magiskpolicy --live "create system_server sdcardfs file" "allow system_server sdcardfs file { write }"
      am force-stop "com.google.android.apps.wellbeing"
    fi
  fi
fi

# Adds slim & full variables to service.sh
for i in "SLIM" "FULL"; do
  sed -i "2i $i=$(eval echo \$$i)" $INSTALLER/common/service.sh
done
cp_ch -n $INSTALLER/common/service.sh $UNITY/service.sh

mkdir -p $INSTALLER/system/bin
cp -f $INSTALLER/common/unityfiles/tools/$ARCH32/xmlstarlet $INSTALLER/system/bin/xmlstarlet
