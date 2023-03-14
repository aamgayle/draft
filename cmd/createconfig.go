package cmd

type CreateConfig struct {
	DeployType            string       `yaml:"deployType"`
	LanguageType          string       `yaml:"languageType"`
	DeployVariables       []UserInputs `yaml:"deployVariables"`
	LanguageVariables     []UserInputs `yaml:"languageVariables"`
	DockerBuildParamsPath string       `yaml:"dockerBuildParamsPath"`
}

type UserInputs struct {
	Name  string `yaml:"name"`
	Value string `yaml:"value"`
}
