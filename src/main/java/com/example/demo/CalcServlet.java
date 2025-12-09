package com.example.demo;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.PrintWriter;

@WebServlet("/calc")
public class CalcServlet extends HttpServlet {
    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        resp.setContentType("text/html;charset=UTF-8");
        String op = req.getParameter("op");
        String aStr = req.getParameter("a");
        String bStr = req.getParameter("b");

        double a = 0, b = 0;
        String error = null;
        try {
            if (aStr != null && !aStr.isEmpty()) a = Double.parseDouble(aStr);
            if (bStr != null && !bStr.isEmpty()) b = Double.parseDouble(bStr);
        } catch (NumberFormatException e) {
            error = "Invalid number format";
        }

        String result = "";
        if (error == null && op != null) {
            switch (op) {
                case "add": result = String.valueOf(a + b); break;
                case "sub": result = String.valueOf(a - b); break;
                case "mul": result = String.valueOf(a * b); break;
                case "div":
                    if (b == 0) result = "Division by zero";
                    else result = String.valueOf(a / b);
                    break;
                default: result = "Unknown operation";
            }
        }

        try (PrintWriter out = resp.getWriter()) {
            out.println("<!doctype html>");
            out.println("<html><head><meta charset=\"utf-8\"><title>Calculator Demo</title></head><body>");
            out.println("<h2>Calculator (GET)</h2>");
            out.println("<form action=\"calc\" method=\"get\">\n");
            out.println("  <input name=\"a\" placeholder=\"a\" value=\"" + (aStr!=null?aStr:"") + "\">\n");
            out.println("  <select name=\"op\">\n");
            out.println("    <option value=\"add\">+</option>\n");
            out.println("    <option value=\"sub\">-</option>\n");
            out.println("    <option value=\"mul\">*</option>\n");
            out.println("    <option value=\"div\">/</option>\n");
            out.println("  </select>\n");
            out.println("  <input name=\"b\" placeholder=\"b\" value=\"" + (bStr!=null?bStr:"") + "\">\n");
            out.println("  <button type=\"submit\">Compute</button>\n");
            out.println("</form>");

            if (error != null) {
                out.println("<p style=\"color:red\">Error: " + error + "</p>");
            } else if (op != null) {
                out.println("<h3>Result: " + result + "</h3>");
            }

            out.println("<p><a href=\"/\">Back to index</a></p>");
            out.println("</body></html>");
        }
    }
}
