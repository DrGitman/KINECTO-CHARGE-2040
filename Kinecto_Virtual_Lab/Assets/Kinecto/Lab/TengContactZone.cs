// Kinecto Virtual Lab: textile TENG zone (shoulder / torso). Counts contact-separation cycles from the arm swing.
using UnityEngine;

public class TengContactZone : MonoBehaviour
{
    public HarvestModel model;
    public Transform swingBone;          // upper arm bone
    public float contactAngle = 12f;     // swing (degrees) that presses the panels together
    public Renderer zoneRenderer;
    public Color idle = new Color(0.56f, 0.83f, 0.77f, 0.3f), active = new Color(0.56f, 0.83f, 0.77f, 1f);

    bool inContact; Quaternion rest;

    void Start() { rest = swingBone.localRotation; }

    void LateUpdate()
    {
        float swing = Quaternion.Angle(rest, swingBone.localRotation);
        if (!inContact && swing > contactAngle) inContact = true;
        else if (inContact && swing < contactAngle * 0.5f)
        {
            inContact = false;
            model.AddTengContact();                         // one contact + separation
            if (zoneRenderer) zoneRenderer.material.color = active;
        }
        if (zoneRenderer) zoneRenderer.material.color = Color.Lerp(zoneRenderer.material.color, idle, Time.deltaTime * 3f);
    }
}
