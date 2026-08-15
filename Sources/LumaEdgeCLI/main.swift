import Foundation
import LumaEdgeCore

let args = Array(CommandLine.arguments.dropFirst())

guard !args.isEmpty else {
    print("""
    LumaEdge CLI - Command Line Automation Interface
    Usage: lumaedge <command> [options]
    
    Commands:
      toggle              Toggles edge lighting on/off
      on                  Turns edge lighting on
      off                 Turns edge lighting off
      preset <id>         Applies a lighting preset by ID (e.g., studio_white, daylight, warm_lamp, sunset)
      brightness <val>    Sets overall edge brightness (0.0 - 1.0)
      kelvin <val>        Sets color temperature in Kelvin (2000 - 10000)
      status              Prints available presets and current state
    """)
    exit(0)
}

func sendIPCCommand(_ dict: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: dict),
          let jsonStr = String(data: data, encoding: .utf8) else {
        return
    }
    DistributedNotificationCenter.default().postNotificationName(
        NSNotification.Name("LumaEdgeIPCCommand"),
        object: jsonStr,
        userInfo: nil,
        deliverImmediately: true
    )
}

let command = args[0].lowercased()

switch command {
case "toggle", "--toggle":
    print("Toggling LumaEdge lighting...")
    sendIPCCommand(["action": "toggle"])
    DistributedNotificationCenter.default().postNotificationName(
        NSNotification.Name("com.lumaedge.cli.toggle"),
        object: nil,
        userInfo: nil,
        deliverImmediately: true
    )
    
case "on":
    print("Turning LumaEdge ON...")
    sendIPCCommand(["action": "on"])
    
case "off":
    print("Turning LumaEdge OFF...")
    sendIPCCommand(["action": "off"])
    
case "preset", "--preset":
    guard args.count > 1 else {
        print("Error: Missing preset ID. Try 'lumaedge preset daylight'")
        exit(1)
    }
    let presetID = args[1]
    print("Applying preset: \(presetID)...")
    sendIPCCommand(["action": "preset", "presetID": presetID])
    DistributedNotificationCenter.default().postNotificationName(
        NSNotification.Name("com.lumaedge.cli.setPreset"),
        object: presetID,
        userInfo: ["presetID": presetID],
        deliverImmediately: true
    )
    
case "brightness":
    guard args.count > 1, let val = Double(args[1]) else {
        print("Error: Missing or invalid brightness value (0.0 - 1.0)")
        exit(1)
    }
    print("Setting brightness to \(val)...")
    sendIPCCommand(["action": "brightness", "value": val])
    
case "kelvin":
    guard args.count > 1, let val = Double(args[1]) else {
        print("Error: Missing or invalid Kelvin value (2000 - 10000)")
        exit(1)
    }
    print("Setting Kelvin temperature to \(val)K...")
    sendIPCCommand(["action": "kelvin", "value": val])
    
case "width", "thickness":
    guard args.count > 1, let val = Double(args[1]) else {
        print("Error: Missing or invalid width/thickness in pixels (16 - 400)")
        exit(1)
    }
    print("Setting edge width to \(Int(val))px...")
    sendIPCCommand(["action": "width", "value": val])
    
case "status":
    print("LumaEdge CLI Status & Available Presets:")
    for p in GlowPreset.builtInPresets {
        print("  - \(p.id): \(p.title) (\(Int(p.kelvinTemp))K, brightness \(Int(p.defaultBrightness * 100))%, width \(Int(p.defaultWidth))px)")
    }
    
default:
    print("Unknown command: \(command). Type 'lumaedge' for help.")
    exit(1)
}
