using Dalamud.Configuration;

namespace AutoBhop;

[Serializable]
public sealed class Configuration : IPluginConfiguration
{
    public int Version { get; set; } = 1;

    /// <summary>
    /// Holding the key is already opt in, so this defaults to on. It exists for the
    /// times you want the key back without unloading the plugin.
    /// </summary>
    public bool Enabled { get; set; } = true;
}
