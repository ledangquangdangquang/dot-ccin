-- Monitor headphone jack: keep NVIDIA HDMI audio profile on so the sink is selectable.
table.insert(alsa_monitor.rules, {
  matches = {{{ "device.name", "equals", "alsa_card.pci-0000_01_00.1" }}},
  apply_properties = { ["device.profile"] = "output:hdmi-stereo" },
})
