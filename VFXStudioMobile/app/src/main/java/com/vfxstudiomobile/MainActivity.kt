package com.vfxstudiomobile
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView

private val bg = Color(0xFF0B0D12)
private val panel = Color(0xFF171C27)
private val accent = Color(0xFF9878FF)
private val muted = Color(0xFF929BAD)
data class MediaLayer(val uri: Uri, val name: String, val type: String)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) { super.onCreate(savedInstanceState); setContent { EditorScreen() } }
}

@Composable
private fun EditorScreen() {
    val context = androidx.compose.ui.platform.LocalContext.current
    val player = remember { ExoPlayer.Builder(context).build() }
    DisposableEffect(Unit) { onDispose { player.release() } }
    var layers by remember { mutableStateOf(listOf<MediaLayer>()) }
    var selected by remember { mutableIntStateOf(-1) }
    var activeTool by remember { mutableStateOf("Edit") }
    var speed by remember { mutableFloatStateOf(1f) }
    var projectName by remember { mutableStateOf("Untitled Project") }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        if (uris.isNotEmpty()) {
            uris.forEach { uri ->
                runCatching { context.contentResolver.takePersistableUriPermission(uri, android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION) }
                val type = context.contentResolver.getType(uri)?.substringBefore("/") ?: "media"
                layers = layers + MediaLayer(uri, uri.lastPathSegment?.substringAfterLast("/") ?: "Media", type.uppercase())
            }
            val video = uris.firstOrNull { context.contentResolver.getType(it)?.startsWith("video/") == true }
            if (video != null) { player.setMediaItem(MediaItem.fromUri(video)); player.prepare() }
            selected = layers.lastIndex
        }
    }
    MaterialTheme(colorScheme = darkColorScheme(primary = accent, background = bg, surface = panel)) {
        Column(Modifier.fillMaxSize().background(bg)) {
            Row(Modifier.fillMaxWidth().height(54.dp).background(panel).padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Column { Text("VFX STUDIO", color = accent, style = MaterialTheme.typography.titleMedium); Text(projectName, color = muted, fontSize = 10.sp) }
                Spacer(Modifier.weight(1f))
                IconButton(onClick = { projectName = if (projectName == "Untitled Project") "New Edit" else "Untitled Project" }) { Icon(Icons.Default.Edit, null, tint = muted) }
                Button(onClick = { picker.launch(arrayOf("video/*", "image/*", "audio/*")) }) { Icon(Icons.Default.Add, null, Modifier.size(16.dp)); Text(" Import", fontSize = 11.sp) }
            }
            Box(Modifier.weight(1f).fillMaxWidth().padding(10.dp).background(Color.Black, RoundedCornerShape(10.dp)), contentAlignment = Alignment.Center) {
                val video = layers.firstOrNull { it.type == "VIDEO" }
                if (video != null) AndroidView(factory = { ctx -> PlayerView(ctx).apply { player = player; useController = true } }, modifier = Modifier.fillMaxSize())
                else Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Default.Movie, null, tint = accent, modifier = Modifier.size(44.dp))
                    Text("Preview Monitor", color = Color.White)
                    Text("Import video to begin", color = muted, fontSize = 11.sp)
                }
            }
            Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("TIMELINE", color = Color.White, fontSize = 11.sp); Spacer(Modifier.weight(1f)); Text("${layers.size} layers", color = muted, fontSize = 10.sp)
            }
            Column(Modifier.heightIn(max = 220.dp).fillMaxWidth().verticalScroll(rememberScrollState())) {
                layers.forEachIndexed { index, layer ->
                    Row(Modifier.fillMaxWidth().padding(horizontal = 9.dp, vertical = 3.dp)
                        .background(if (selected == index) Color(0xFF283047) else panel, RoundedCornerShape(7.dp))
                        .clickable {
                            selected = index
                            if (layer.type == "VIDEO") { player.setMediaItem(MediaItem.fromUri(layer.uri)); player.prepare() }
                        }.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(if (layer.type == "AUDIO") Icons.Default.MusicNote else Icons.Default.Movie, null, tint = accent, modifier = Modifier.size(17.dp))
                        Spacer(Modifier.width(8.dp))
                        Column(Modifier.weight(1f)) { Text(layer.name, color = Color.White, fontSize = 11.sp, maxLines = 1); Text(layer.type, color = muted, fontSize = 9.sp) }
                        IconButton(onClick = { layers = layers.toMutableList().also { it.removeAt(index) }; selected = -1 }, modifier = Modifier.size(28.dp)) {
                            Icon(Icons.Default.Delete, null, tint = muted, modifier = Modifier.size(15.dp))
                        }
                    }
                }
            }
            Row(Modifier.fillMaxWidth().background(panel).horizontalScroll(rememberScrollState()).padding(7.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf("Edit", "Trim", "Speed", "Color", "Audio", "Text", "Canvas", "Effects").forEach { tool ->
                    FilterChip(selected = activeTool == tool, onClick = { activeTool = tool }, label = { Text(tool, fontSize = 10.sp) })
                }
            }
            when (activeTool) {
                "Speed" -> Column(Modifier.fillMaxWidth().background(panel).padding(12.dp)) {
                    Text("Playback speed: %.2fx".format(speed), color = Color.White, fontSize = 11.sp)
                    Slider(value = speed, onValueChange = { speed = it; player.setPlaybackSpeed(it) }, valueRange = 0.25f..3f)
                }
                "Audio" -> Text("Import audio from the + button above.", color = muted, fontSize = 10.sp, modifier = Modifier.padding(12.dp))
                else -> Text("$activeTool tools · editing engine integration in progress", color = muted, fontSize = 10.sp, modifier = Modifier.padding(12.dp))
            }
        }
    }
}
