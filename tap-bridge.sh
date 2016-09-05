#!/bin/bash

# Copyright (c) 2016 Nikita Shpak aka eqlbin
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
# and associated documentation files (the "Software"), to deal in the Software without restriction, 
# including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
# and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, 
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial 
# portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT 
# NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


#
# Данный скрипт при запуске с параметром up создает ethernet-мост с именем из переменной $BR,
# создает виртуальные tap-интерфейсы с именами из списка $VIFS и правами для пользователя $USER,
# добавляет виртуальные и реальный интерфейсы в созданный мост и производит установку IP-адресов
# и шлюза по умолчанию. Адреса берутся либо из переменных $GATEWAY и $IFADDRS или же автоматически
# из вывода команд ip route и ip addr (см. ниже).
#
# При запуске скрипта с параметром down, он выполняет обратные действия, а именно, удаляет сетевой
# мост и устанавливает IP-адреса и адрес шлюза по умолчанию по тому же принципу, по которому они
# устанавливались при запуске с параметром up.
#

# имя реального сетевого интерфейса, который должен быть введен в мост
IF="eth0"

# список виртуальных tap-интерфейсов, которые надо создать (через пробел)
VIFS="tap0 tap1 tap2"

# имя моста
BR="br0"

# имя пользователя, которому должны быть отданы права на tap-интерфейсы
USER="eqlbin"

# адрес шлюза по умолчанию
# например, 192.168.1.1
GATEWAY=""

# список ip-адресов с указанием маски, которые должны быть назначены мосту (через пробел)
# например, 192.168.1.5/24 192.168.200.5/24
IFADDRS=""

# ВАЖНО!
# Если значения переменных $GATEWAY или $IFADDRS являются пустыми строками, то скрипт будет
# пытаться использовать для моста $BR IP-адреса, которые в данный момент назначены интерфейсу $IF
# и адрес шлюза, который используется в системе в данный момент.
# Эти адреса берутся из вывода команд ip addr и ip route, а не из конфигурационных файлов, вроде /etc/network/interfaces!

function up(){

  modprobe tun

  if [ -z "$IFADDRS" ]; then
    IFADDRS=`ip addr show dev $IF | grep -E -o "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2}"`
  fi

  if [ -z "$GATEWAY" ]; then
    GATEWAY=`ip route | grep default | grep -E -o "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"`
  fi

  brctl addbr $BR

  for VIF in $VIFS
  do
    tunctl -t $VIF -u $USER
    ifconfig $VIF 0.0.0.0 up
    brctl addif $BR $VIF
  done

  brctl addif $BR $IF
  ip addr flush dev $IF
  ifconfig $BR up

  for IP in $IFADDRS
  do
    ip addr add $IP dev $BR
    sleep 0.1
  done

  [[ -z "$GATEWAY" ]] || ip route add default via $GATEWAY dev $BR
}

function down(){

  if [ -z "$IFADDRS" ]; then
    IFADDRS=`ip addr show dev $BR | grep -E -o "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2}"`
  fi

  if [ -z "$GATEWAY" ]; then
    GATEWAY=`ip route | grep default | grep -E -o "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"`
  fi

  ifconfig $BR down

  for VIF in $VIFS
  do
    brctl delif $BR $VIF
    tunctl -d $VIF
  done

  brctl delif $BR $IF
  brctl delbr $BR

  for IP in $IFADDRS
  do
    ip addr add $IP dev $IF
    sleep 0.1
  done

  [[ -z "$GATEWAY" ]] || ip route add default via $GATEWAY dev $IF
}

case $1 in
  up)
      up
  ;;
  down)
      down
  ;;
  *)
      echo "Usage: $0 up or $0 down"
esac
