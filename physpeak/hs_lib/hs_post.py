from hs_ast import AST_node, AST_state
import hs_gen

def AST_post_2(node):

    if node.children:

        for child in node.children:

            if child.type == "flow":

                if child.leaf == "continue":
                    if not child.children:
                        child.children = [AST_node("number", None, 1)]

                elif child.leaf == "break":
                    if not child.children:
                        child.children = [AST_node("number", None, 1)]

                elif child.leaf == "return":
                    if not child.children:
                        child.children = [AST_node("number", None, 1)]

    if node.children:
        for child in node.children:
            AST_post_2(child)

def AST_post_3(node):

    if node.children:

        for child in node.children:

            if \
            child.type != "function" and \
            child.type != "value":
                continue

            if child.leaf in AST_state.scripts:
                p_func = AST_state.scripts[child.leaf]
            elif child.leaf in AST_state.functions:
                p_func = AST_state.functions[child.leaf]
            else:
                continue

            if p_func.n_args < 0:
                continue

            p_args = p_func.args.copy()

            while len(p_args) < p_func.n_args:
                p_args.append(AST_node("number", None, 0))

            if child.children:
                for i in range(min(len(p_args), len(child.children))):
                    p_args[i] = child.children[i]

            if p_args:
                child.children = p_args
            else:
                child.children = None

    if node.children:
        for child in node.children:
            AST_post_3(child)

def AST_post():

    # patch flow calls
    AST_post_2(AST_state.root)

    # default arguments for calls
    AST_post_3(AST_state.root)
