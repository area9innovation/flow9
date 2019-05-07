package dk.area9.flowrunner;
import android.os.Bundle;
import android.preference.CheckBoxPreference;
import android.preference.EditTextPreference;
import android.preference.PreferenceActivity;
import android.preference.PreferenceCategory;
import android.preference.PreferenceScreen;
import android.text.InputType;

public class FlowPreferenceActivity extends PreferenceActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {       
        super.onCreate(savedInstanceState);       
        PreferenceScreen screen = getPreferenceManager().createPreferenceScreen(this);
        
        PreferenceCategory general_category = new PreferenceCategory(this);
        general_category.setTitle("Flow General");
        screen.addPreference(general_category);

        EditTextPreference override_loader_url = new EditTextPreference(this);
        override_loader_url.setTitle("Override loader URL (empty = default)");
        override_loader_url.setKey("pref_override_loader_url");
        override_loader_url.setDefaultValue("");
        general_category.addPreference(override_loader_url);
        
        EditTextPreference url_params = new EditTextPreference(this);
        url_params.setTitle("URL parameters");
        url_params.setKey("pref_url_parameters");
        general_category.addPreference(url_params);

        CheckBoxPreference opengl_video = new CheckBoxPreference(this);
        opengl_video.setDefaultValue(true);
        opengl_video.setTitle("OpenGL Video");
        opengl_video.setKey("opengl_video");
        general_category.addPreference(opengl_video);

        // Profiling
        PreferenceCategory profiling_category = new PreferenceCategory(this);
        profiling_category.setTitle("Flow Profiling");
        screen.addPreference(profiling_category);
        
        CheckBoxPreference time_profile = new CheckBoxPreference(this);
        time_profile.setDefaultValue(false);
        time_profile.setTitle("Flow time profiling");
        time_profile.setKey("pref_flow_time_profile");

        EditTextPreference time_profile_trace_per = new EditTextPreference(this);
        time_profile_trace_per.getEditText().setInputType(InputType.TYPE_CLASS_NUMBER);
        time_profile_trace_per.setDefaultValue("5000");
        time_profile_trace_per.setTitle("Instructions per profiling sample (integer)");
        time_profile_trace_per.setKey("pref_flow_time_profile_trace_per");
        
        CheckBoxPreference http_profile = new CheckBoxPreference(this);
        http_profile.setDefaultValue(false);
        http_profile.setTitle("Flow HTTP request profiling (accessible via logcat)");
        http_profile.setKey("pref_flow_http_profile");
        
        profiling_category.addPreference(time_profile);
        profiling_category.addPreference(time_profile_trace_per);
        profiling_category.addPreference(http_profile);

        setPreferenceScreen(screen);
    }
}
