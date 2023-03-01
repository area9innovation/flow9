class CheckVersion
{
	static double JenkinsVersion = 55.0;

	public static void main (String[] args) throws java.lang.Exception
	{
		double version = Double.parseDouble(System.getProperty("java.class.version"));
		if (version > JenkinsVersion) {
			System.out.println("Jenkins only recognizes class file versions up to " + JenkinsVersion + ". Your version is " + version);
			System.out.println("DO NOT PUSH your jar file to repo!!!");
			System.exit(1);
		} else {
			System.exit(0);
		}
	}
}
