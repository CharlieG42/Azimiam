package wildzimut.azimiam

// v0.7.1 : FlutterFragmentActivity (et non FlutterActivity) est exigé par le
// plugin health 13.1.3 — la demande d’autorisation Santé Connect passe par
// registerForActivityResult, fiable uniquement sur une FragmentActivity ;
// avec FlutterActivity elle échouait silencieusement (aucun écran, l’app
// n’apparaissait jamais dans Santé Connect).
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity()
