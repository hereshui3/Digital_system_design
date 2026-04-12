set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports clock]

set_property -dict {PACKAGE_PIN P5  IOSTANDARD LVCMOS33} [get_ports {switch[0]}]
set_property -dict {PACKAGE_PIN P4  IOSTANDARD LVCMOS33} [get_ports {switch[1]}]

## Blue[0]
set_property -dict {PACKAGE_PIN C7  IOSTANDARD LVCMOS33} [get_ports {disp_RGB[2]}]

## Green[0]
set_property -dict {PACKAGE_PIN B6  IOSTANDARD LVCMOS33} [get_ports {disp_RGB[1]}]

## Red[0]
set_property -dict {PACKAGE_PIN F5  IOSTANDARD LVCMOS33} [get_ports {disp_RGB[0]}]

set_property -dict {PACKAGE_PIN D7  IOSTANDARD LVCMOS33} [get_ports hsync]
set_property -dict {PACKAGE_PIN C4  IOSTANDARD LVCMOS33} [get_ports vsync]