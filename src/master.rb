i2c = I2C.new(22, 21)
dps310 = DPS310.new(i2c)

while true do
  dps310.temp_meas
  dps310.pres_meas

  puts "TEMP=#{dps310.temp}"
  puts "PRES=#{dps310.pres}"

  sleep 1
end
