
'TODO　防止超时死机
'内存超限我不想管。限制内存有些难。

Dim WS, FSO, StdOut
Set WS = CreateObject("WScript.Shell")
Set FSO = CreateObject("Scripting.FileSystemObject")
Set StdIn = FSO.GetStandardStream(0)
Set StdOut = FSO.GetStandardStream(1)
Set StdErr = FSO.GetStandardStream(2)



Function ForceConsole()
	If InStr(LCase(WScript.FullName), "cscript.exe") = 0 Then
		WS.Run "cmd /c cscript.exe /NoLogo " & WScript.ScriptFullName
		WScript.Quit
	End If
End Function

Sub LoadWerFaultKiller()
	SimpleExec "cmd /c cscript.exe /NoLogo " & WScript.ScriptFullName & " WerFaultKiller"
End Sub

Function SimpleExec(Cmd)
	Dim Sh
	Set Sh = WS.Exec(Cmd)
	With Sh
		.StdIn.Close
		.StdOut.Close
		.StdErr.Close
	End With
	Set SimpleExec = Sh
End Function

Function WithExitCodeExec(Cmd)
	Dim Sh
	Set Sh = WS.Exec(Cmd)
	With Sh
		.StdIn.Close
		.StdOut.Close
	End With
	WScript.Echo Sh.StdErr.ReadAll()
	Sh.StdErr.Close
	WithExitCodeExec = Sh.ExitCode
End Function


Sub WerFaultKiller()
	' 抄来的
	Dim objWMIService, colMonitoredProcesses, objLatestProcess
	Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
	Set colMonitoredProcesses = objWMIService.ExecNotificationQuery("select * from __instancecreationevent within 1 where TargetInstance isa 'Win32_Process'")
	Do
		Set objLatestProcess = colMonitoredProcesses.NextEvent
		If LCase(objLatestProcess.TargetInstance.Name) = "werfault.exe" Then objLatestProcess.TargetInstance.Terminate
	Loop
End Sub

Function GetOutput(Cmd, Input, LimitTime, WithExitCode, Tag)
	Dim Sh, InFile, OutFile, Str, TmpOut, ShKiller
	Set Sh = WS.Exec(Cmd)
	Set InFile = Sh.StdIn
	Set OutFile = Sh.StdOut

	' 超时检测！
	'If LimitTime = True Then
	'	Set ShKiller = SimpleExec("wscript.exe " & WScript.ScriptFullName & " DelayedKiller " & Sh.ProcessID)
	'End If	

	' 如果程序不接受输入，那么没办法写入管道，甚至有可能没法读
	On Error Resume Next
	InFile.Write Input
	InFile.Close
	Sh.StdErr.Close
	TmpOut = RTrim(OutFile.ReadAll())
	On Error Goto 0
	
	
	' 等待程序执行完成
	Do Until Sh.Status = 1 
		WScript.Sleep 16
	Loop 
	
	'If LimitTime = True Then
	'	On Error Resume Next
	'	ShKiller.Terminate
	'	On Error Goto 0
	'End If	


	' 检查错误码，并且附加相应信息
	If (WithExitCode = True) Then TmpOut = TmpOut & Chr(13) & Chr(10) & "结束代码：" & Hex(Sh.ExitCode) & Chr(13) & Chr(10)
	If (WithExitCode = True)And (Sh.ExitCode <> 0) Then TmpOut = TmpOut & Chr(13) & Chr(10) & Tag & Chr(13) & Chr(10)
	GetOutput = TmpOut
End Function

Sub TryReBuild()
	Dim A
	A = WithExitCodeExec("cmd /c gcc -Wall -Wextra standard.c -o standard.exe")
	If A <> 0 Then
		WScript.Echo "standard.c 编译错误。按回车键继续。" & Chr(7)
		StdIn.ReadLine
		TryReBuild
		Exit Sub
	End If
	A = WithExitCodeExec("cmd /c gcc -Wall -Wextra test.c -o test.exe")
	If A <> 0 Then
		WScript.Echo "test.c 编译错误。按回车键继续。" & Chr(7)
		StdIn.ReadLine
		TryReBuild
		Exit Sub
	End If
	A = WithExitCodeExec("cmd /c gcc -Wall -Wextra gen.c -o gen.exe")
	If A <> 0 Then
		WScript.Echo "gen.c 编译错误。按回车键继续。" & Chr(7)
		StdIn.ReadLine
		TryReBuild
		Exit Sub
	End If
End Sub

Function DiffAndShowError(TestInput, Opt1, Opt2)
	If Opt1 <> Opt2 Then
		WScript.Echo "------------输入------------"
		WScript.Echo TestInput
		WScript.Echo "---------standard.exe-------"
		WScript.Echo Opt1
		WScript.Echo "----------test.exe----------"
		WScript.Echo Opt2
		WScript.Echo "------------结束------------"
		WScript.Echo ""
		WScript.Echo "???   WA   ???"
		WScript.Echo "两份输出不一样。"
		WScript.Echo "按回车键继续。" & Chr(7)
		StdIn.ReadLine
		DiffAndShowError = True
	Else
		DiffAndShowError = False
	End If
	
End Function

Sub RunNormal()



	ForceConsole
	TryReBuild
	LoadWerFaultKiller
	Do
		StdOut.Write "."
		Dim TestInput, Opt1, Opt2, T
		TestInput = GetOutput("gen.exe", "", False, False, "Gen")
		Opt1 = RTrim(GetOutput("standard.exe", TestInput, True, True, "Std"))
		Opt2 = RTrim(GetOutput("test.exe", TestInput, True, True, "Tst"))
		
		If DiffAndShowError(TestInput, Opt1, Opt2) = True Then TryReBuild
	Loop
End Sub





If WScript.Arguments.Count = 0 Then
	RunNormal
Else 
	Select Case WScript.Arguments(0)
		Case "WerFaultKiller"
			WerFaultKiller
		Case "DelayedKiller"
			WScript.Sleep 3200
			SimpleExec "taskkill /f /t /pid " & WScript.Arguments(1)
		Case Else
			WScript.Echo "错误：不支持的命令参数"
	End Select
End If




' 测试机器！规则：待定

