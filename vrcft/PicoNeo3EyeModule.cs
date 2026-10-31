// VRCFaceTracking module for the Pico Neo 3 Pro Eye.
// Receives the PEYE UDP packets sent by eyestream (running on the headset) and
// feeds gaze + openness into VRCFT.
//
// Packet: PEYE,seq,time_s,ok,comb_status,l_status,r_status,gx,gy,gz,px,py,pz,l_open,r_open
// gaze is the combined gaze direction in Unity axes (+x right, +y up, +z forward).

using System;
using System.Globalization;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using Microsoft.Extensions.Logging;
using VRCFaceTracking;
using VRCFaceTracking.Core.Library;
using VRCFaceTracking.Core.Types;

namespace PicoNeo3EyeModule
{
    public class PicoNeo3EyeModule : ExtTrackingModule
    {
        const int Port = 7777;
        // Gaze is sent to VRCFT as tan(angle); clamp to about +-60 degrees
        const float MaxTan = 1.7f;

        // Pico reports openness as 0 or 1 only; ease towards it so blinks don't snap.
        // Time constants in seconds: closing is quick, opening a little slower.
        const float CloseTau = 0.025f;
        const float OpenTau = 0.045f;

        UdpClient _udp;
        DateTime _lastPacket = DateTime.MinValue;
        bool _receiving;
        float _leftOpen = 1f, _rightOpen = 1f;
        // Debounce: an eye only changes open/closed after 2 frames agree, which hides
        // the open/closed flicker Pico reports right as the lid covers the pupil
        readonly Debounce _leftState = new Debounce(), _rightState = new Debounce();
        DateTime _lastSmooth = DateTime.UtcNow;

        public override (bool SupportsEye, bool SupportsExpression) Supported => (true, false);

        public override (bool eyeSuccess, bool expressionSuccess) Initialize(bool eyeAvailable, bool expressionAvailable)
        {
            ModuleInformation.Name = "Pico Neo 3 Pro Eye";
            try
            {
                _udp = new UdpClient(new IPEndPoint(IPAddress.Any, Port));
                _udp.Client.ReceiveTimeout = 200;
            }
            catch (Exception e)
            {
                Logger.LogError("Pico Neo 3 Eye: can't listen on UDP {Port} ({Message}). Is pico_eye_receiver.py still running?", Port, e.Message);
                return (false, false);
            }
            Logger.LogInformation("Pico Neo 3 Eye: listening on UDP {Port}", Port);
            return (true, false);
        }

        public override void Update()
        {
            byte[] data;
            try
            {
                IPEndPoint from = null;
                data = _udp.Receive(ref from);
            }
            catch (SocketException)
            {
                // timeout: no packet in 200 ms
                if (_receiving && DateTime.UtcNow - _lastPacket > TimeSpan.FromSeconds(2))
                {
                    _receiving = false;
                    Logger.LogWarning("Pico Neo 3 Eye: no data from headset. Is eyestream running?");
                }
                return;
            }
            catch (ObjectDisposedException)
            {
                Thread.Sleep(100);
                return;
            }

            string[] p = Encoding.ASCII.GetString(data).Trim().Split(',');
            if (p.Length != 15 || p[0] != "PEYE") return;

            var ci = CultureInfo.InvariantCulture;
            if (!float.TryParse(p[7], NumberStyles.Float, ci, out float gx) ||
                !float.TryParse(p[8], NumberStyles.Float, ci, out float gy) ||
                !float.TryParse(p[9], NumberStyles.Float, ci, out float gz) ||
                !float.TryParse(p[13], NumberStyles.Float, ci, out float lo) ||
                !float.TryParse(p[14], NumberStyles.Float, ci, out float ro))
                return;
            bool ok = p[3] == "1";

            _lastPacket = DateTime.UtcNow;
            if (!_receiving)
            {
                _receiving = true;
                Logger.LogInformation("Pico Neo 3 Eye: receiving data");
            }

            var now = DateTime.UtcNow;
            float dt = (float)Math.Min((now - _lastSmooth).TotalSeconds, 0.1);
            _lastSmooth = now;
            _leftOpen = Ease(_leftOpen, _leftState.Update(lo > 0.5f) ? 1f : 0f, dt);
            _rightOpen = Ease(_rightOpen, _rightState.Update(ro > 0.5f) ? 1f : 0f, dt);

            var eye = UnifiedTracking.Data.Eye;
            eye.Left.Openness = _leftOpen;
            eye.Right.Openness = _rightOpen;

            // Gaze only updates on valid frames; during a blink the eyes keep their last direction
            if (ok && gz > 0.1f)
            {
                var gaze = new Vector2(
                    Math.Clamp(gx / gz, -MaxTan, MaxTan),
                    Math.Clamp(gy / gz, -MaxTan, MaxTan));
                eye.Left.Gaze = gaze;
                eye.Right.Gaze = gaze;
            }
        }

        class Debounce
        {
            bool _state = true, _pending = true;
            int _count;

            public bool Update(bool raw)
            {
                if (raw == _state) { _count = 0; _pending = raw; return _state; }
                _count = raw == _pending ? _count + 1 : 1;
                _pending = raw;
                if (_count >= 2) { _state = raw; _count = 0; }
                return _state;
            }
        }

        static float Ease(float current, float target, float dt)
        {
            float tau = target < current ? CloseTau : OpenTau;
            return current + (target - current) * (1f - MathF.Exp(-dt / tau));
        }

        public override void Teardown()
        {
            _udp?.Close();
            _udp?.Dispose();
            _udp = null;
        }
    }
}
