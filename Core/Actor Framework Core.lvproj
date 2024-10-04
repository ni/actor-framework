<?xml version='1.0' encoding='UTF-8'?>
<Project Type="Project" LVVersion="20008000">
	<Property Name="NI.LV.All.SaveVersion" Type="Str">20.0</Property>
	<Property Name="NI.LV.All.SourceOnly" Type="Bool">true</Property>
	<Property Name="NI.Project.Description" Type="Str"></Property>
	<Item Name="My Computer" Type="My Computer">
		<Property Name="server.app.propertiesEnabled" Type="Bool">true</Property>
		<Property Name="server.control.propertiesEnabled" Type="Bool">true</Property>
		<Property Name="server.tcp.enabled" Type="Bool">false</Property>
		<Property Name="server.tcp.port" Type="Int">0</Property>
		<Property Name="server.tcp.serviceName" Type="Str">My Computer/VI Server</Property>
		<Property Name="server.tcp.serviceName.default" Type="Str">My Computer/VI Server</Property>
		<Property Name="server.vi.callsEnabled" Type="Bool">true</Property>
		<Property Name="server.vi.propertiesEnabled" Type="Bool">true</Property>
		<Property Name="specify.custom.address" Type="Bool">false</Property>
		<Item Name="Additional Messages" Type="Folder">
			<Item Name="Batch Msg.lvclass" Type="LVClass" URL="../ActorFramework/Batch Msg/Batch Msg.lvclass"/>
			<Item Name="Reply Msg.lvclass" Type="LVClass" URL="../ActorFramework/Reply Msg/Reply Msg.lvclass"/>
			<Item Name="Report Error Msg.lvclass" Type="LVClass" URL="../ActorFramework/Report Error Msg/Report Error Msg.lvclass"/>
			<Item Name="Self-Addressed Msg.lvclass" Type="LVClass" URL="../ActorFramework/Self-Addressed Msg/Self-Addressed Msg.lvclass"/>
		</Item>
		<Item Name="Time-Delayed Send Message" Type="Folder">
			<Item Name="Time-Delay Override Options.ctl" Type="VI" URL="../ActorFramework/Time-Delayed Send Message/Time-Delay Override Options.ctl"/>
			<Item Name="Time-Delayed Send Message Core.vi" Type="VI" URL="../ActorFramework/Time-Delayed Send Message/Time-Delayed Send Message Core.vi"/>
			<Item Name="Time-Delayed Send Message.vi" Type="VI" URL="../ActorFramework/Time-Delayed Send Message/Time-Delayed Send Message.vi"/>
		</Item>
		<Item Name="Actor Framework.lvlib" Type="Library" URL="../ActorFramework/Actor Framework.lvlib"/>
		<Item Name="AF Debug.lvlib" Type="Library" URL="../AFDebug/AF Debug.lvlib"/>
		<Item Name="Dependencies" Type="Dependencies">
			<Item Name="vi.lib" Type="Folder">
				<Item Name="Error Cluster From Error Code.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/error.llb/Error Cluster From Error Code.vi"/>
				<Item Name="Get LV Class Name.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/LVClass/Get LV Class Name.vi"/>
				<Item Name="High Resolution Relative Seconds.vi" Type="VI" URL="/&lt;vilib&gt;/Utility/High Resolution Relative Seconds.vi"/>
				<Item Name="NI_SystemLogging.lvlib" Type="Library" URL="/&lt;vilib&gt;/Utility/SystemLogging/NI_SystemLogging.lvlib"/>
			</Item>
			<Item Name="LV Config Read String.vi" Type="VI" URL="/&lt;resource&gt;/dialog/lvconfig.llb/LV Config Read String.vi"/>
			<Item Name="systemLogging.dll" Type="Document" URL="systemLogging.dll">
				<Property Name="NI.PreserveRelativePath" Type="Bool">true</Property>
			</Item>
		</Item>
		<Item Name="Build Specifications" Type="Build"/>
	</Item>
</Project>
