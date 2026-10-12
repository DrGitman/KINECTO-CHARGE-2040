// Kinecto Virtual Lab: keyboard / gamepad input through the new Input System (the project has the old Input class off).
// WASD / arrows move, Shift runs, Space jumps, E taps the cuff, Q cycles the jacket mode, Tab shows / hides the panels.
using UnityEngine;
using UnityEngine.InputSystem;

public static class LabInput
{
    static Keyboard K => Keyboard.current;
    static Gamepad G => Gamepad.current;

    // Automated play-test hooks (used by the editor test driver; zero / off in normal play)
    public static Vector2 SimAxis; public static bool SimRun;
    static int simJumpFrame = -1, simTapFrame = -1;
    public static void SimJump() => simJumpFrame = Time.frameCount + 1;
    public static void SimTap() => simTapFrame = Time.frameCount + 1;

    static float Axis(Key neg, Key neg2, Key pos, Key pos2, float pad, float sim)
    {
        float v = 0f;
        if (K != null)
        {
            if (K[neg].isPressed || K[neg2].isPressed) v -= 1f;
            if (K[pos].isPressed || K[pos2].isPressed) v += 1f;
        }
        if (Mathf.Abs(pad) > 0.2f) v = pad;
        if (Mathf.Abs(sim) > 0.01f) v = sim;
        return Mathf.Clamp(v, -1f, 1f);
    }

    public static float Horizontal => Axis(Key.A, Key.LeftArrow, Key.D, Key.RightArrow, G != null ? G.leftStick.x.ReadValue() : 0f, SimAxis.x);
    public static float Vertical => Axis(Key.S, Key.DownArrow, Key.W, Key.UpArrow, G != null ? G.leftStick.y.ReadValue() : 0f, SimAxis.y);
    public static bool Run => (K != null && (K.leftShiftKey.isPressed || K.rightShiftKey.isPressed)) || (G != null && G.leftStickButton.isPressed) || SimRun;
    public static bool TapPressed => (K != null && K.eKey.wasPressedThisFrame) || (G != null && G.buttonWest.wasPressedThisFrame) || Time.frameCount == simTapFrame;
    public static bool ModePressed => (K != null && K.qKey.wasPressedThisFrame) || (G != null && G.buttonNorth.wasPressedThisFrame);
    public static bool JumpPressed => (K != null && K.spaceKey.wasPressedThisFrame) || (G != null && G.buttonSouth.wasPressedThisFrame) || Time.frameCount == simJumpFrame;
    public static bool PanelPressed => (K != null && K.tabKey.wasPressedThisFrame) || (G != null && G.startButton.wasPressedThisFrame);
}
