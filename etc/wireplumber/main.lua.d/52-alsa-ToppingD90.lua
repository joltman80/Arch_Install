rule_ToppingD90 = {
    matches = {
      {
        { "node.name", "equals", "alsa_output.usb-Topping_D90-00.iec958-stereo" },
      },
    },
    apply_properties = {
      ["audio.allowed-rates"] = "44100,48000,88200,96000,176400,192000,352800,384000,768000",
    },
  }
  
  table.insert(alsa_monitor.rules,rule_ToppingD90)
  