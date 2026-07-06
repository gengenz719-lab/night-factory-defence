using UnityEngine;

namespace NightFactoryDefence
{
    // 効果音。音声ファイルを使わず、実行時にPCMを合成してAudioClipを作る(スプライトと同じ流儀)。
    // 各所(射撃/着弾/死亡/建設/レリック/勝敗)はここを呼ぶだけ。
    public sealed class NfdAudioManager : MonoBehaviour
    {
        const int Rate = 44100;

        public static NfdAudioManager Instance { get; private set; }

        AudioSource src;
        AudioClip shoot, hit, death, build, relic, win, lose;
        float lastShoot;

        void Awake()
        {
            Instance = this;
            src = gameObject.AddComponent<AudioSource>();
            src.playOnAwake = false;
            src.spatialBlend = 0f; // 2D

            shoot = Blip(820f, 240f, 0.08f, square: true);
            hit = NoiseBurst(0.05f, 12f, highTick: true);
            death = NoiseBurst(0.22f, 5f, downTone: true);
            build = Blip(180f, 120f, 0.1f, square: true, thud: true);
            relic = Arp(new[] { 523f, 659f, 784f }, 0.32f);
            win = Arp(new[] { 523f, 659f, 784f, 1046f }, 0.5f);
            lose = Sweep(420f, 90f, 0.6f);
        }

        void OnDestroy()
        {
            if (Instance == this) Instance = null;
        }

        // --- 再生窓口 ---

        public void Shoot()
        {
            if (Time.unscaledTime - lastShoot < 0.03f) return; // 連射でも鳴りすぎないよう間引く
            lastShoot = Time.unscaledTime;
            Play(shoot, 0.22f, Random.Range(0.94f, 1.06f));
        }

        public void Hit() => Play(hit, 0.28f, Random.Range(0.95f, 1.1f));
        public void Death() => Play(death, 0.35f, Random.Range(0.9f, 1.05f));
        public void Build() => Play(build, 0.5f, 1f);
        public void Relic() => Play(relic, 0.5f, 1f);
        public void Win() => Play(win, 0.6f, 1f);
        public void Lose() => Play(lose, 0.6f, 1f);

        void Play(AudioClip clip, float volume, float pitch)
        {
            if (clip == null || src == null) return;
            src.pitch = pitch;
            src.PlayOneShot(clip, volume);
        }

        // --- 合成 ---

        // 音程が下がる短いブリップ(射撃・建設)
        AudioClip Blip(float f0, float f1, float dur, bool square, bool thud = false)
        {
            var n = Mathf.CeilToInt(Rate * dur);
            var data = new float[n];
            var phase = 0f;
            for (var i = 0; i < n; i++)
            {
                var t = (float)i / n;
                var freq = Mathf.Lerp(f0, f1, t);
                phase += freq / Rate * Mathf.PI * 2f;
                var wave = square ? Mathf.Sign(Mathf.Sin(phase)) : Mathf.Sin(phase);
                var env = Mathf.Exp(-t * (thud ? 6f : 9f)) * (1f - t);
                data[i] = wave * env * 0.5f;
            }
            return Make("blip", data);
        }

        // ノイズの破裂(着弾・死亡)
        AudioClip NoiseBurst(float dur, float decay, bool highTick = false, bool downTone = false)
        {
            var n = Mathf.CeilToInt(Rate * dur);
            var data = new float[n];
            var phase = 0f;
            for (var i = 0; i < n; i++)
            {
                var t = (float)i / n;
                var env = Mathf.Exp(-t * decay);
                var noise = Random.Range(-1f, 1f);
                var s = noise * env * 0.5f;
                if (highTick && i < Rate * 0.008f) s += 0.5f * env; // 立ち上がりのカチッ
                if (downTone)
                {
                    var freq = Mathf.Lerp(300f, 70f, t);
                    phase += freq / Rate * Mathf.PI * 2f;
                    s += Mathf.Sin(phase) * env * 0.5f;
                }
                data[i] = Mathf.Clamp(s, -1f, 1f);
            }
            return Make("noise", data);
        }

        // 上昇アルペジオ(レリック・勝利)
        AudioClip Arp(float[] notes, float dur)
        {
            var n = Mathf.CeilToInt(Rate * dur);
            var data = new float[n];
            var per = dur / notes.Length;
            for (var i = 0; i < n; i++)
            {
                var t = (float)i / Rate;
                var idx = Mathf.Clamp(Mathf.FloorToInt(t / per), 0, notes.Length - 1);
                var localT = (t - idx * per) / per;
                var env = Mathf.Exp(-localT * 4f);
                var s = Mathf.Sin(t * notes[idx] * Mathf.PI * 2f) * env * 0.4f;
                data[i] = s;
            }
            return Make("arp", data);
        }

        // 下降スイープ(敗北)
        AudioClip Sweep(float f0, float f1, float dur)
        {
            var n = Mathf.CeilToInt(Rate * dur);
            var data = new float[n];
            var phase = 0f;
            for (var i = 0; i < n; i++)
            {
                var t = (float)i / n;
                var freq = Mathf.Lerp(f0, f1, t);
                phase += freq / Rate * Mathf.PI * 2f;
                var env = (1f - t) * 0.5f;
                data[i] = Mathf.Sin(phase) * env;
            }
            return Make("sweep", data);
        }

        AudioClip Make(string name, float[] data)
        {
            var clip = AudioClip.Create(name, data.Length, 1, Rate, false);
            clip.SetData(data, 0);
            return clip;
        }
    }
}
