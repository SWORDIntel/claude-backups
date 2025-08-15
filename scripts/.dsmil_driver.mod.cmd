savedcmd_dsmil_driver.mod := printf '%s\n'   dsmil_driver.o | awk '!x[$$0]++ { print("./"$$0) }' > dsmil_driver.mod
