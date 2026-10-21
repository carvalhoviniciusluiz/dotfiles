{
	// Gerado pelo install.sh. O Sublime aberto pelo Dock não lê o PATH do ~/.zshrc;
	// por isso os caminhos do Node do asdf são fixos.
	// Se o projeto tiver prettier em node_modules, o JsPrettier usa o local primeiro.
	"node_path": "{{NODE_BIN}}/node",
	"prettier_cli_path": "{{NODE_BIN}}/prettier",

	// Formata ao salvar só em projetos que têm configuração do Prettier.
	"auto_format_on_save": true,
	"auto_format_on_save_requires_prettier_config": true,
}
