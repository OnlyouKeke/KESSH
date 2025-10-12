"use strict";
var __spreadArray = (this && this.__spreadArray) || function (to, from, pack) {
    if (pack || arguments.length === 2) for (var i = 0, l = from.length, ar; i < l; i++) {
        if (ar || !(i in from)) {
            if (!ar) ar = Array.prototype.slice.call(from, 0, i);
            ar[i] = from[i];
        }
    }
    return to.concat(ar || Array.prototype.slice.call(from));
};
exports.__esModule = true;
var ts = require("typescript");
var typescript_1 = require("typescript");
var fs = require("fs");
var path = require("path");
var extensionName = ".ts";
var callFunctionUtil = 'CallFunctionUtil';
var callMethod = 'call';
var importObjectName = 'ImportObject';
var cloudObjectMethods = [];
var printer = createPrinter();
var printLog = false;
var useCallFunction = false;
var Context = (function () {
    function Context() {
    }
    return Context;
}());
var functionPath = process.argv[2];
checkIsDirectory(functionPath);
var cloudObjectName = path.basename(functionPath);
console.info("cloud object: ".concat(cloudObjectName));
var exportDir = process.argv[3];
checkIsDirectory(exportDir);
var declarationDir = path.join(exportDir, 'declarationDir');
var _a = parseFunctionConfig(functionPath), moduleName = _a[0], handler = _a[1];
var cloudObjectPath = '';
if (path.basename(exportDir) == 'cloud_objects') {
    cloudObjectPath = path.join(exportDir, 'src/main/ets');
}
else {
    cloudObjectPath = path.join(exportDir, 'cloudobject');
}
var basePath = path.join(cloudObjectPath, cloudObjectName);
var cloudFunctionEntryPath = path.join(functionPath, moduleName + '.ts');
console.info("cloudFunctionEntryPath: ".concat(cloudFunctionEntryPath));
emitDeclaration(declarationDir);
var handlerDts = path.join(declarationDir, moduleName + '.d.ts');
console.info("handler dts ".concat(handlerDts));
parseDts(handlerDts, { declaration: new Map() });
if (useCallFunction) {
    createCallFunctionUtil(callFunctionUtil);
}
else {
    createImportObject(importObjectName);
}
removeDir(declarationDir);
writeIndex();
console.log("The Invoke Interface for CloudObject: ".concat(cloudObjectName, " generated in directory: ").concat(path.resolve(cloudObjectPath), " successfully."));
function writeIndex() {
    var indexPath = path.join(exportDir, 'Index.ets');
    if (!fs.existsSync(indexPath)) {
        return;
    }
    var sourceCode = fs.readFileSync(indexPath, 'utf-8');
    var exportImportObject = "export { importObject } from './src/main/ets/ImportObject';";
    if (!sourceCode.includes(exportImportObject)) {
        sourceCode = sourceCode + '\n' + exportImportObject;
    }
    var exportCode = "export { ".concat(handler, " } from './src/main/ets/").concat(cloudObjectName, "/").concat(moduleName, "';");
    if (sourceCode.includes(exportCode)) {
        return;
    }
    sourceCode = sourceCode + '\n' + exportCode;
    writeFileSync(indexPath, sourceCode);
}
function writeFileSync(callFunctionFile, content) {
    console.log("------ writeFileSync ".concat(callFunctionFile, " ------\n"));
    console.log("".concat(content));
    fs.writeFileSync(callFunctionFile, content);
}
function createCallFunctionUtil(fileName) {
    var callFunctionFile = path.join(basePath, fileName + '.ts');
    var content = '';
    if (printLog) {
        var callFunctionPrintLog = ["import hilog from '@ohos.hilog';\n", "hilog.debug(0x0000, 'callFunction', 'input: '+ JSON.stringify(input));", "hilog.debug(0x0000, 'callFunction', 'response: ' + JSON.stringify(res.getValue()));\n            "
        ];
        content += getCallFunctionModule(getMethods(), callFunctionPrintLog);
    }
    else {
        content += getCallFunctionModule(getMethods());
    }
    writeFileSync(callFunctionFile, content);
}
function createImportObject(fileName) {
    var callFunctionFile = path.join(cloudObjectPath, fileName + extensionName);
    var print = printLog ? "console.log('callFunction input: ' + JSON.stringify(input));\n" : '';
    var content = getImportObjectModule(print);
    writeFileSync(callFunctionFile, content);
}
function emitDeclaration(declarationDir) {
    compileCloudFunction(cloudFunctionEntryPath, {
        allowJs: true,
        declaration: true,
        emitDeclarationOnly: true,
        skipLibCheck: true,
        declarationDir: declarationDir
    });
}
function compileCloudFunction(entry, options) {
    var dts = {};
    var host = ts.createCompilerHost(options);
    var program = ts.createProgram([entry], options, host);
    program.emit();
    return dts;
}
function writeFile(file, content) {
    var cloudObjectEtsDir = path.join(basePath, path.relative(declarationDir, path.dirname(file)));
    if (!fileExists(cloudObjectEtsDir)) {
        fs.mkdirSync(cloudObjectEtsDir, { recursive: true });
    }
    var writeFileName = path.join(cloudObjectEtsDir, path.basename(file, '.d.ts') + extensionName);
    writeFileSync(writeFileName, content);
}
function analyzeDependency(node, file, context) {
    node.forEachChild(function (importDeclarationChild) {
        if (ts.isStringLiteral(importDeclarationChild)) {
            var text = importDeclarationChild.text;
            if (!text.startsWith('.')) {
                console.error("Dependency Error! Can not have third-party dependencies!");
                console.error("Dependency Error! file: ".concat(file, " import third-party dependency: ").concat(text));
                process.exit(100);
            }
            var dirname = path.dirname(file);
            if (!fileExists(dirname)) {
                console.error("Dependency Error! can't find ".concat(dirname));
                process.exit(100);
            }
            var dependency = path.join(dirname, text + '.d.ts');
            if (!context.declaration.get(dependency)) {
                console.log("file ".concat(file, " import ").concat(dependency));
                parseDts(dependency, context);
            }
        }
    });
}
function modifyDeclaredHandlerClass(node, printer, sourceFile) {
    var publicMethods = cloudObjectMethods;
    for (var _i = 0, _a = node.members; _i < _a.length; _i++) {
        var member = _a[_i];
        if (ts.isMethodDeclaration(member)) {
            if (!member.modifiers || member.modifiers.length == 0) {
                var myType = member.type;
                var isPromise = false;
                if (ts.isTypeReferenceNode(myType)) {
                    if (ts.isIdentifier(myType.typeName)) {
                        if (myType.typeName.escapedText === "Promise") {
                            isPromise = true;
                        }
                    }
                }
                if (!isPromise) {
                    myType = typescript_1.factory.createTypeReferenceNode(typescript_1.factory.createIdentifier("Promise"), [member.type]);
                }
                publicMethods.push(typescript_1.factory.createMethodSignature(undefined, member.name, member.questionToken, member.typeParameters, member.parameters, myType));
            }
        }
    }
    var interfaceDeclaration = typescript_1.factory.createInterfaceDeclaration(__spreadArray([], node.modifiers.filter(function (modify) { return modify.kind != ts.SyntaxKind.DeclareKeyword; }), true), node.name, undefined, undefined, publicMethods);
    return printer.printNode(ts.EmitHint.Unspecified, interfaceDeclaration, sourceFile);
}
function modifyDeclaredDependenceClass(node, printer, sourceFile) {
    var publicProperties = [];
    for (var _i = 0, _a = node.members; _i < _a.length; _i++) {
        var member = _a[_i];
        if (ts.isPropertyDeclaration(member)) {
            if (!member.modifiers || member.modifiers.length == 0) {
                publicProperties.push(typescript_1.factory.createPropertySignature(undefined, member.name, member.questionToken, member.type));
            }
        }
    }
    var declaredDependenceClass = typescript_1.factory.createInterfaceDeclaration(__spreadArray([], node.modifiers.filter(function (modify) { return modify.kind != ts.SyntaxKind.DeclareKeyword; }), true), node.name, undefined, undefined, publicProperties);
    return printer.printNode(ts.EmitHint.Unspecified, declaredDependenceClass, sourceFile);
}
function createPrinter() {
    return ts.createPrinter({ newLine: ts.NewLineKind.LineFeed });
}
function createFilterPrinter() {
    var isCloudObject = false;
    var isDependencyClass = false;
    return ts.createPrinter({ newLine: ts.NewLineKind.LineFeed }, {
        onEmitNode: function (hint, node, emitCallback) {
            if (ts.isClassDeclaration(node)) {
                if (node.name.text === handler) {
                    isCloudObject = true;
                    emitCallback(hint, node);
                    isCloudObject = false;
                }
                else {
                    isDependencyClass = true;
                    emitCallback(hint, node);
                    isDependencyClass = false;
                }
            }
            else if (ts.isPropertyDeclaration(node)) {
                if (isDependencyClass) {
                    if (!node.modifiers) {
                        emitCallback(hint, node);
                    }
                }
            }
            else if (ts.isMethodDeclaration(node)) {
                if (isCloudObject) {
                    emitCallback(hint, node);
                }
            }
            else if (ts.isConstructorDeclaration(node)) {
            }
            else {
                emitCallback(hint, node);
            }
        }
    });
}
function isCloudObjectEntryModule(file) {
    return path.basename(file, '.d.ts') === moduleName;
}
function getText(node) {
    return printer.printNode(ts.EmitHint.Unspecified, node, undefined);
}
function getMethods() {
    var result = [];
    for (var _i = 0, cloudObjectMethods_1 = cloudObjectMethods; _i < cloudObjectMethods_1.length; _i++) {
        var method = cloudObjectMethods_1[_i];
        result.push(getText(method.name));
    }
    return '\'' + result.join('\' | \'') + '\'';
}
function generateImplementation() {
    var members = [];
    for (var _i = 0, cloudObjectMethods_2 = cloudObjectMethods; _i < cloudObjectMethods_2.length; _i++) {
        var method = cloudObjectMethods_2[_i];
        var properties = [
            typescript_1.factory.createPropertyAssignment(typescript_1.factory.createIdentifier("method"), typescript_1.factory.createNoSubstitutionTemplateLiteral(getText(method.name), getText(method.name)))
        ];
        if (method.parameters && method.parameters.length != 0) {
            var elements = [];
            for (var _a = 0, _b = method.parameters; _a < _b.length; _a++) {
                var parameter = _b[_a];
                elements.push(typescript_1.factory.createIdentifier(getText(parameter.name)));
            }
            properties.push(typescript_1.factory.createPropertyAssignment(typescript_1.factory.createIdentifier("params"), typescript_1.factory.createArrayLiteralExpression(elements, false)));
        }
        var methodDeclaration = typescript_1.factory.createMethodDeclaration(undefined, undefined, method.name, undefined, undefined, method.parameters, method.type, typescript_1.factory.createBlock([typescript_1.factory.createReturnStatement(typescript_1.factory.createAsExpression(typescript_1.factory.createCallExpression(typescript_1.factory.createIdentifier(callMethod), undefined, [typescript_1.factory.createObjectLiteralExpression(properties, true)]), method.type))], true));
        members.push(methodDeclaration);
    }
    var cloudObjectImpl = typescript_1.factory.createClassDeclaration([typescript_1.factory.createToken(ts.SyntaxKind.ExportKeyword)], typescript_1.factory.createIdentifier("".concat(handler, "Impl")), undefined, [typescript_1.factory.createHeritageClause(ts.SyntaxKind.ImplementsKeyword, [typescript_1.factory.createExpressionWithTypeArguments(typescript_1.factory.createIdentifier(handler), undefined)])], members);
    return printer.printNode(ts.EmitHint.Unspecified, cloudObjectImpl, undefined);
}
function exportInstance() {
    var exportInstanceNode = typescript_1.factory.createVariableStatement([typescript_1.factory.createToken(ts.SyntaxKind.ExportKeyword)], typescript_1.factory.createVariableDeclarationList([typescript_1.factory.createVariableDeclaration(typescript_1.factory.createIdentifier("".concat(handler).toLowerCase()), undefined, typescript_1.factory.createTypeReferenceNode(typescript_1.factory.createIdentifier("".concat(handler)), undefined), typescript_1.factory.createNewExpression(typescript_1.factory.createIdentifier("".concat(handler, "Impl")), undefined, []))], ts.NodeFlags.Let));
    return printer.printNode(ts.EmitHint.Unspecified, exportInstanceNode, undefined);
}
function generateImplementationClass(node, sourceFile) {
    var publicMethods = [];
    for (var _i = 0, _a = node.members; _i < _a.length; _i++) {
        var member = _a[_i];
        if (ts.isMethodDeclaration(member)) {
            if (!member.modifiers || member.modifiers.length == 0) {
                var myType = member.type;
                var isPromise = false;
                if (ts.isTypeReferenceNode(myType)) {
                    if (ts.isIdentifier(myType.typeName)) {
                        if (myType.typeName.escapedText === "Promise") {
                            isPromise = true;
                        }
                    }
                }
                if (!isPromise) {
                    myType = typescript_1.factory.createTypeReferenceNode(typescript_1.factory.createIdentifier("Promise"), [member.type]);
                }
                var addMethod = typescript_1.factory.createMethodDeclaration([typescript_1.factory.createModifier(ts.SyntaxKind.PublicKeyword), typescript_1.factory.createModifier(ts.SyntaxKind.AsyncKeyword)], undefined, member.name.getText(sourceFile), member.questionToken, member.typeParameters, member.parameters, myType, typescript_1.factory.createBlock([typescript_1.factory.createReturnStatement(typescript_1.factory.createCallExpression(typescript_1.factory.createPropertyAccessExpression(typescript_1.factory.createIdentifier("Promise"), typescript_1.factory.createIdentifier("reject")), undefined, [typescript_1.factory.createNewExpression(typescript_1.factory.createIdentifier("Error"), undefined, [typescript_1.factory.createStringLiteral("Method not implemented.", true)])]))], true));
                var leadingComments = ts.getCommentRange(member);
                publicMethods.push(ts.setCommentRange(addMethod, leadingComments));
            }
        }
    }
    var interfaceImpl = typescript_1.factory.createClassDeclaration(__spreadArray([], node.modifiers.filter(function (modify) { return modify.kind != ts.SyntaxKind.DeclareKeyword; }), true), node.name, undefined, [typescript_1.factory.createHeritageClause(ts.SyntaxKind.ImplementsKeyword, [typescript_1.factory.createExpressionWithTypeArguments(typescript_1.factory.createIdentifier("CloudObjectLikely"), undefined)])], __spreadArray([typescript_1.factory.createPropertyDeclaration([typescript_1.factory.createModifier(ts.SyntaxKind.PublicKeyword)], typescript_1.factory.createIdentifier("name"), undefined, undefined, typescript_1.factory.createStringLiteral(cloudObjectName, true))], publicMethods, true));
    return printer.printNode(ts.EmitHint.Unspecified, interfaceImpl, sourceFile);
}
function parseDts(file, context) {
    context.declaration.set(file, file);
    var program = ts.createProgram([file], { allowJs: true });
    var sourceFile = program.getSourceFile(file);
    var content = "/*\n * Copyright (c) Huawei Technologies Co., Ltd. 2020-2024. All rights reserved.\n * Generated by the Cloud Object compiler. DO NOT EDIT!\n */\n";
    var exportSpecifiers = [];
    if (isCloudObjectEntryModule(file)) {
        if (useCallFunction) {
            content += "import { ".concat(callMethod, " } from './").concat(callFunctionUtil, "';\n");
        }
        else {
            content += "import type { CloudObjectLikely } from '../".concat(importObjectName, "';\n");
        }
    }
    ts.forEachChild(sourceFile, function (node) {
        if (ts.isImportDeclaration(node)) {
            analyzeDependency(node, file, context);
            content += printer.printNode(ts.EmitHint.Unspecified, node, sourceFile) + '\n';
        }
        else if (ts.isClassDeclaration(node)) {
            if (node.name.text === handler) {
                if (useCallFunction) {
                    content += '\n' + modifyDeclaredHandlerClass(node, printer, sourceFile) + '\n';
                    content += '\n' + generateImplementation() + '\n';
                    content += '\n' + exportInstance() + '\n\n';
                }
                else {
                    content += '\n' + generateImplementationClass(node, sourceFile) + '\n';
                }
            }
            else {
                content += modifyDeclaredDependenceClass(node, printer, sourceFile) + '\n';
            }
        }
        else if (ts.isExportDeclaration(node)) {
            node.exportClause.forEachChild(function (exportNode) {
                exportSpecifiers.push(exportNode);
            });
        }
        else {
            content += printer.printNode(ts.EmitHint.Unspecified, node, sourceFile) + '\n';
        }
    });
    if (exportSpecifiers.length > 0) {
        var exportDeclaration = typescript_1.factory.createExportDeclaration(undefined, false, typescript_1.factory.createNamedExports(exportSpecifiers), undefined, undefined);
        content += printer.printNode(ts.EmitHint.Unspecified, exportDeclaration, sourceFile) + '\n';
    }
    writeFile(file, content);
}
function parseFunctionConfig(modulePath) {
    try {
        var functionConfigPath = path.join(modulePath, "function-config.json");
        var functionConfigContent = fs.readFileSync(functionConfigPath, 'utf8');
        var functionConfig = JSON.parse(functionConfigContent);
        if (!functionConfig.hasOwnProperty('handler')) {
            console.error("Get function-config handler properties failed!.");
            process.exit(-1);
        }
        var _a = functionConfig.handler.split('.'), moduleName_1 = _a[0], handler_1 = _a[1];
        console.info("moduleName: ".concat(moduleName_1, ", handler: ").concat(handler_1));
        return [moduleName_1.charAt(0).toUpperCase() + moduleName_1.slice(1), handler_1];
    }
    catch (e) {
        console.error("parse function-config.json file failed!", e);
        process.exit(-1);
    }
}
function checkIsDirectory(dirPath) {
    var stats = fs.lstatSync(dirPath);
    if (!stats.isDirectory()) {
        console.error("File at ".concat(dirPath, " is not a directory."));
        process.exit(-1);
    }
}
function fileExists(path) {
    try {
        fs.accessSync(path);
        return true;
    }
    catch (error) {
        return false;
    }
}
function removeDir(dir) {
    var files = fs.readdirSync(dir);
    for (var _i = 0, files_1 = files; _i < files_1.length; _i++) {
        var file = files_1[_i];
        var newPath = path.join(dir, file);
        if (fs.statSync(newPath).isDirectory()) {
            removeDir(newPath);
        }
        else {
            fs.unlinkSync(newPath);
        }
    }
    fs.rmdirSync(dir);
}
function isUpperCase(ch) {
    return ch >= 'A' && ch <= 'Z';
}
function getCallFunctionModule(methods, print) {
    if (print === void 0) { print = ['', '', '']; }
    return "/*\n * Copyright (c) Huawei Technologies Co., Ltd. 2020-2024. All rights reserved.\n * Generated by the Cloud Object compiler. DO NOT EDIT!\n */\nimport { BusinessError } from '@kit.BasicServicesKit';\nimport { cloudFunction } from '@kit.CloudFoundationKit';\n".concat(print[0], "\nconst cloudObject = '").concat(cloudObjectName, "';\ntype methodType = ").concat(methods, ";\n\ninterface callParameter {\n    method: methodType\n    params?: Object[]\n}\n\nfunction call(params: callParameter): Promise<Object> {\n    return new Promise<Object>((resolve, reject) => {\n        let input = {\n            name: cloudObject,\n            params: params\n        };\n        ").concat(print[1], "\n        cloudFunction.call(input).then((value: cloudFunction.FunctionResult) => {\n            ").concat(print[2], "resolve(value.result);\n        }).catch((err: BusinessError) => {\n            reject(err);\n        })\n    });\n}\n\nexport { call, callParameter, cloudObject, methodType };");
}
function getImportObjectModule(printLog) {
    if (printLog === void 0) { printLog = ''; }
    return "/*\n * Copyright (c) Huawei Technologies Co., Ltd. 2020-2024. All rights reserved.\n * Generated by the Cloud Object compiler. DO NOT EDIT!\n */\nimport type { BusinessError } from '@kit.BasicServicesKit';\nimport { cloudFunction } from '@kit.CloudFoundationKit';\n\nexport interface CloudObjectLikely {\n  name: string;\n}\n\nfunction mockMethod<T extends CloudObjectLikely>(target: T, version: string,\n  prop: string | symbol): (...args: unknown[]) => Promise<unknown> {\n  return async (...args: unknown[]) => new Promise((resolve, reject) => {\n    cloudFunction.call({\n      name: target.name,\n      version: version,\n      data: {\n        method: prop,\n        params: args\n      }\n    }).then((value: cloudFunction.FunctionResult) => {\n      resolve(value.result);\n    }).catch((err: BusinessError) => {\n      reject(err);\n    });\n  });\n}\n\nexport function importObject<T extends CloudObjectLikely>(tClass: new () => T, version = '$latest'): T {\n  return new Proxy<T>(new tClass(), {\n    get(target, prop): (...args: unknown[]) => Promise<unknown> {\n      return mockMethod<T>(target, version, prop);\n    }\n  });\n}\n";
}
