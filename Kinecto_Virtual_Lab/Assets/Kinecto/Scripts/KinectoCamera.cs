using UnityEngine;
using UnityEngine.InputSystem;

namespace Kinecto
{
    /// Third-person orbit camera: mouse to look (cursor locked), scroll to zoom. Never passes through solid objects:
    /// it pulls in at once when a wall/tree/door is between it and the student, then eases back out smoothly.
    public class KinectoCamera : MonoBehaviour
    {
        public Transform target; public float height = 1.55f, distance = 3.6f, minDist = 1.2f, maxDist = 8f;
        public float sensitivity = 0.12f; public bool lookLocked;
        float yaw, pitch = 12f, current = -1f;
        Vector3 pivotSmooth; bool hasPivot;

        void Start() { if (target) yaw = target.eulerAngles.y; SetCursor(true); }

        public static void SetCursor(bool locked) { Cursor.lockState = locked ? CursorLockMode.Locked : CursorLockMode.None; Cursor.visible = !locked; }

        void LateUpdate()
        {
            if (!target) return;
            var m = Mouse.current;
            if (m != null && !lookLocked)
            {
                Vector2 d = m.delta.ReadValue() * sensitivity;
                yaw += d.x; pitch = Mathf.Clamp(pitch - d.y, -25f, 70f);
                distance = Mathf.Clamp(distance - m.scroll.ReadValue().y * 0.004f, minDist, maxDist);
            }
            Quaternion rot = Quaternion.Euler(pitch, yaw, 0);
            Vector3 want = target.position + Vector3.up * height;
            // tiny smoothing on the pivot removes step/stair jitter without adding lag
            pivotSmooth = hasPivot ? Vector3.Lerp(pivotSmooth, want, 1f - Mathf.Exp(-25f * Time.deltaTime)) : want; hasPivot = true;
            Vector3 dir = -(rot * Vector3.forward);
            float dist = distance;
            foreach (var h in Physics.SphereCastAll(pivotSmooth, 0.25f, dir, distance, ~0, QueryTriggerInteraction.Ignore))
                if (!h.transform.IsChildOf(target) && h.distance > 0f) dist = Mathf.Min(dist, Mathf.Max(h.distance - 0.1f, 0.3f));
            if (current < 0f || dist < current) current = dist;                        // blocked: snap in (never clip)
            else current = Mathf.Lerp(current, dist, 1f - Mathf.Exp(-6f * Time.deltaTime));   // free: ease back out
            transform.SetPositionAndRotation(pivotSmooth + dir * current, rot);
        }
    }
}
