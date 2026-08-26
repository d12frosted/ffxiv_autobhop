using AutoBhop.Core;
using Dalamud.Game.ClientState.Conditions;
using Dalamud.Game.ClientState.Keys;
using Dalamud.Plugin;
using Dalamud.Plugin.Services;
using FFXIVClientStructs.FFXIV.Client.Game;
using FFXIVClientStructs.FFXIV.Client.UI;

namespace AutoBhop;

public sealed class Plugin : IDalamudPlugin
{
    private const string CommandName = "/autobhop";

    /// <summary>
    /// Row 2 of the GeneralAction sheet. Rows 1 to 3 (auto-attack, jump, limit break)
    /// carry no Action row of their own; the client handles them itself, and UseAction
    /// is the way to ask for one.
    /// </summary>
    private const uint JumpGeneralAction = 2;

    private readonly IDalamudPluginInterface pluginInterface;
    private readonly ICommandManager commands;
    private readonly IFramework framework;
    private readonly ICondition condition;
    private readonly IKeyState keyState;
    private readonly IClientState clientState;
    private readonly IChatGui chat;

    private readonly Configuration configuration;

    public Plugin(
        IDalamudPluginInterface pluginInterface,
        ICommandManager commands,
        IFramework framework,
        ICondition condition,
        IKeyState keyState,
        IClientState clientState,
        IChatGui chat)
    {
        this.pluginInterface = pluginInterface;
        this.commands = commands;
        this.framework = framework;
        this.condition = condition;
        this.keyState = keyState;
        this.clientState = clientState;
        this.chat = chat;

        this.configuration = pluginInterface.GetPluginConfig() as Configuration ?? new Configuration();

        this.commands.AddHandler(CommandName, new Dalamud.Game.Command.CommandInfo(OnCommand)
        {
            HelpMessage = "Toggle auto bunnyhop. No argument reports the current state.",
        });

        this.framework.Update += OnUpdate;
    }

    public void Dispose()
    {
        this.framework.Update -= OnUpdate;
        this.commands.RemoveHandler(CommandName);
    }

    private void OnCommand(string command, string arguments)
    {
        var argument = arguments.Trim().ToLowerInvariant();
        this.configuration.Enabled = argument switch
        {
            "on" or "enable" => true,
            "off" or "disable" => false,
            "" => !this.configuration.Enabled,
            _ => this.configuration.Enabled,
        };

        this.pluginInterface.SavePluginConfig(this.configuration);
        this.chat.Print($"autobhop is {(this.configuration.Enabled ? "on" : "off")}.");
    }

    private void OnUpdate(IFramework _)
    {
        if (!this.configuration.Enabled) return;
        if (!BhopGate.ShouldJump(Read())) return;

        unsafe
        {
            var actions = ActionManager.Instance();
            if (actions is null) return;
            actions->UseAction(ActionType.GeneralAction, JumpGeneralAction);
        }
    }

    /// <summary>
    /// One read of the world per frame. The game clears its key state array when the
    /// window loses focus, so alt-tabbing away is handled for free and there is no
    /// need to ask the OS which window is in front.
    /// </summary>
    private BhopSnapshot Read()
    {
        bool textInputActive;
        unsafe
        {
            var atk = RaptureAtkModule.Instance();
            textInputActive = atk is not null && atk->IsTextInputActive();
        }

        return new BhopSnapshot(
            JumpKeyHeld: this.keyState[VirtualKey.SPACE],
            TextInputActive: textInputActive,
            InFlight: this.condition[ConditionFlag.InFlight],
            Jumping: this.condition.Any(ConditionFlag.Jumping, ConditionFlag.Jumping61),
            Occupied: this.condition.Any(
                ConditionFlag.Occupied,
                ConditionFlag.Occupied30,
                ConditionFlag.Occupied33,
                ConditionFlag.Occupied38,
                ConditionFlag.Occupied39,
                ConditionFlag.OccupiedInEvent,
                ConditionFlag.OccupiedInQuestEvent,
                ConditionFlag.OccupiedInCutSceneEvent,
                ConditionFlag.OccupiedSummoningBell,
                ConditionFlag.WatchingCutscene,
                ConditionFlag.WatchingCutscene78),
            BetweenAreas: this.condition.Any(ConditionFlag.BetweenAreas, ConditionFlag.BetweenAreas51),
            LoggedIn: this.clientState.IsLoggedIn);
    }
}
