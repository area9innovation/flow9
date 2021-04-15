package dk.area9.flowrunner;

import androidx.annotation.Nullable;

import java.lang.reflect.Constructor;
import java.lang.reflect.InvocationTargetException;

public class FlowGooglePlayServicesFactory {
    private final static String FLOW_GOOGLE_PLAY_SERVICES = "dk.area9.flowrunner.FlowGooglePlayServices";
    private final static String FLOW_GOOGLE_PLAY_SERVICES_STUB = "dk.area9.flowrunner.FlowGooglePlayServicesStub";

    @Nullable
    public static IFlowGooglePlayServices getFlowGooglePlayServices(FlowRunnerActivity activity) {
        IFlowGooglePlayServices result;
        try {
            Class<?> flowGooglePlayServices = Class.forName(FLOW_GOOGLE_PLAY_SERVICES);
            Constructor<?> constructor = flowGooglePlayServices.getDeclaredConstructors()[0];
            constructor.setAccessible(true);
            result = (IFlowGooglePlayServices)constructor.newInstance(activity);
        }  catch (ClassNotFoundException e) {
            result = null;
        } catch (IllegalArgumentException e) {
            result = null;
        } catch (IllegalAccessException e) {
            result = null;
        } catch (InstantiationException e) {
            result = null;
        } catch (InvocationTargetException e) {
            result = null;
        }
        if (result != null) {
            return result;
        }

        try {
            result = (IFlowGooglePlayServices)Class.forName(FLOW_GOOGLE_PLAY_SERVICES_STUB).newInstance();
        }  catch (ClassNotFoundException e) {
            result = null;
        } catch (IllegalArgumentException e) {
            result = null;
        } catch (IllegalAccessException e) {
            result = null;
        } catch (InstantiationException e) {
            result = null;
        }
        return result;
    }
}
