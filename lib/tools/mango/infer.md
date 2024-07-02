@run<flowcpp --batch mango/mango.flow -- grammar=mango/mango.mango poppy=1 types=1>
// @run<flowcpp --batch mango/mango.flow -- grammar=mango/mango.mango poppy=1 types=2>

// This one has some manual changes
@run<flowcpp --batch mango/mango.flow -- grammar=poppy/poppy.mango poppy=1 types=1 typeprefix=Poppy>
// @run<flowcpp --batch mango/mango.flow -- grammar=poppy/poppy.mango poppy=1 types=2 typeprefix=Poppy>

@run<flowcpp --batch mango/mango.flow -- grammar=melon/melon.mango poppy=1 types=1>
// @run<flowcpp --batch mango/mango.flow -- grammar=melon/melon.mango poppy=1 types=2>

@run<flowcpp --batch mango/mango.flow -- grammar=lisp/lisp.mango poppy=1 types=1 typeprefix=Lisp_>
// @run<flowcpp --batch mango/mango.flow -- grammar=lisp/lisp.mango poppy=1 types=2 typeprefix=Lisp_>

@run<flowcpp --batch mango/mango.flow -- grammar=kiwi/kiwi.mango poppy=1 types=1>
// @run<flowcpp --batch mango/mango.flow -- grammar=kiwi/kiwi.mango poppy=1 types=2>

@run<flowcpp --batch mango/mango.flow -- grammar=syntaxes/json/json.mango poppy=1 types=1 typeprefix=JSON_>
// @run<flowcpp --batch mango/mango.flow -- grammar=syntaxes/json/json.mango poppy=1 types=2 typeprefix=JSON_>

@run<flowcpp --batch mango/mango.flow -- grammar=prolog/prolog.mango poppy=1 types=1 typeprefix=Pro_>
// @run<flowcpp --batch mango/mango.flow -- grammar=prolog/prolog.mango poppy=1 types=2 typeprefix=Pro_>

// This one requires Lisp types:
// @run<flowcpp --batch mango/mango.flow -- grammar=rewrite/rewrite.mango poppy=1 types=1 typeprefix=Rewrite_>
// @run<flowcpp --batch mango/mango.flow -- grammar=rewrite/rewrite.mango poppy=1 types=2 typeprefix=Rewrite_>

@run<flowcpp --batch mango/mango.flow -- grammar=runcore/value.mango poppy=1 types=1 typeprefix=Core>
// @run<flowcpp --batch mango/mango.flow -- grammar=runcore/value.mango poppy=1 types=2 typeprefix=Core>

@run<flowcpp --batch mango/mango.flow -- grammar=basil/basil.mango poppy=1 types=1>
// @run<flowcpp --batch mango/mango.flow -- grammar=basil/basil.mango poppy=1 types=2>

@run<flowcpp --batch mango/mango.flow -- grammar=blueprint/blueprint.mango poppy=1 types=1>
// @run<flowcpp --batch mango/mango.flow -- grammar=blueprint/blueprint.mango poppy=1 types=2>

// @run<flowcpp --batch mango/mango.flow -- grammar=syntaxes/flow/flow.mango poppy=1 types=1 typeprefix=F9_>
@run<flowcpp --batch mango/mango.flow -- grammar=syntaxes/xml/xml.mango poppy=1 types=1 typeprefix=XML_>
@run<flowcpp --batch mango/mango.flow -- grammar=seed/include.mango poppy=1 types=1>

// @run<flowcpp --batch mango/mango.flow -- grammar=seed/blueprint.mango poppy=1 types=1>

@run<flowcpp --batch mango/mango.flow -- grammar=syntaxes/matique/matique.mango types=1 typeprefix=Mq poppy=1>
